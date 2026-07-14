//
//  ConversationSyncService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

final class ConversationSyncService: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    private static let coalescer = KeyedCoalescer<String, Conversation>()
    private static let recentlyFailedSyncRecords = LockIsolated(Set<SynchronizationRecord>())

    private let _syncData = LockIsolated<ConversationSyncData?>(nil)

    // MARK: - Computed Properties

    private var syncData: ConversationSyncData? {
        get { _syncData.wrappedValue }
        set { _syncData.wrappedValue = newValue }
    }

    // MARK: - Synchronize Conversation

    func synchronizeConversation(
        _ conversation: Conversation
    ) async throws(Exception) -> Conversation {
        try await Self.coalescer(conversation.id.key) { [weak self] () async throws(Exception) -> Conversation in
            guard let self else {
                throw Exception(
                    "Service has been deallocated.",
                    metadata: .init(sender: Self.self)
                )
            }

            guard !Self
                .recentlyFailedSyncRecords
                .wrappedValue
                .contains(where: {
                    $0.conversationIDKey == conversation.id.key && !$0.isExpired
                }) else {
                Logger.log(
                    .init(
                        "Conversation recently failed sync; temporarily ignoring updates.",
                        isReportable: false,
                        userInfo: [
                            "ConversationIDHash": conversation.id.hash,
                            "ConversationIDKey": conversation.id.key,
                        ],
                        metadata: .init(sender: self)
                    ),
                    domain: .conversationSync
                )

                return conversation
            }

            do throws(Exception) {
                return try await _synchronizeConversation(conversation)
            } catch {
                Self.recentlyFailedSyncRecords.projectedValue.withValue {
                    $0 = $0.filter { !$0.isExpired }

                    let previousAttempt = $0.first(
                        where: { $0.conversationIDKey == conversation.id.key }
                    )?.attempt ?? 0

                    $0.remove(.init(conversationIDKey: conversation.id.key))
                    $0.insert(.init(
                        conversationIDKey: conversation.id.key,
                        attempt: previousAttempt + 1
                    ))
                }

                throw error
            }
        }
    }

    // MARK: - Synchronization

    private func synchronizeActivities() async throws(Exception) {
        guard let newActivities = syncData?.newData[
            Conversation.SerializableKey.activities.rawValue
        ] as? [[String: Any]] else {
            throw .Networking.decodingFailed(
                data: syncData?.newData ?? [:],
                .init(sender: self)
            )
        }

        let updatedActivities = try await newActivities.map {
            try await Activity(from: $0)
        }

        guard let conversation = syncData?.conversation.modifyKey(
            .activities,
            withValue: updatedActivities
        ) else {
            throw .Networking.typeMismatch(
                key: Conversation.SerializableKey.activities.rawValue,
                type: type(of: updatedActivities),
                .init(sender: self)
            )
        }

        syncData = .init(
            conversation,
            messages: syncData?.messages ?? [],
            newData: syncData?.newData ?? [:]
        )
    }

    private func synchronizeData() async throws(Exception) {
        try await synchronizeActivities()
        try await synchronizeParticipants()
        try await synchronizeMetadata()
        try await synchronizeReactionMetadata()
        try synchronizeHash()
    }

    private func synchronizeHash() throws(Exception) {
        guard let syncData else {
            throw .Networking.decodingFailed(
                data: syncData?.newData ?? [:],
                .init(sender: self)
            )
        }

        // Use the server hash (from the user's conversationIDs) as the
        // conversation's id.hash so archive lookups match on the server
        // hash rather than the client-computed encodedHash. This avoids
        // writing back to openConversations and triggering a self-event.
        let serverHash = clientSession
            .user
            .currentUser?
            .conversationIDs?
            .first(where: { $0.key == syncData.conversation.id.key })?
            .hash ?? syncData.conversation.encodedHash

        self.syncData = .init(
            .init(
                .init(
                    key: syncData.conversation.id.key,
                    hash: serverHash
                ),
                activities: syncData.conversation.activities,
                messageIDs: syncData.conversation.messageIDs,
                metadata: syncData.conversation.metadata,
                participants: syncData.conversation.participants,
                reactionMetadata: syncData.conversation.reactionMetadata
            ),
            messages: syncData.messages,
            newData: syncData.newData
        )
    }

    private func synchronizeMessages(
        _ messageIDs: [String],
        lastTenOnly: Bool = false
    ) async throws(Exception) {
        guard let conversation = syncData?.conversation else {
            throw Exception(
                "Failed to resolve conversation in sync data.",
                metadata: .init(sender: self)
            )
        }

        // Firebase push IDs are chronologically ordered, so
        // sorted map keys give ascending sent-order by
        // construction — reversed()[0...9] is genuinely the
        // newest ten.
        var messageIDs = messageIDs
        if lastTenOnly,
           messageIDs.count >= 10 {
            messageIDs = Array(messageIDs.reversed()[0 ... 9])
        }

        let messages = try await networking.messageService.getMessages(
            ids: messageIDs
        )

        let updatedMessages = ((syncData?.messages ?? []) + messages)
            .filteringSystemMessages
            .uniquedByID
            .sortedByAscendingSentDate

        // Use the server's authoritative message IDs rather
        // than rebuilding from fetched messages. The server
        // map is the source of truth for which IDs exist.
        let serverMessageIDs: [String] = if let map = syncData?.newData[
            Conversation.SerializableKey.messages.rawValue
        ] as? [String: Any] {
            map.keys.sorted()
        } else {
            conversation.messageIDs
        }

        let updatedConversation = conversation.copying(
            messageIDs: serverMessageIDs
        )

        syncData = .init(
            updatedConversation,
            messages: updatedMessages,
            newData: syncData?.newData ?? [:]
        )

        try synchronizeHash()
    }

    private func synchronizeMetadata() async throws(Exception) {
        guard let newMetadata = syncData?.newData[
            Conversation.SerializableKey.metadata.rawValue
        ] as? [String: Any] else {
            throw .Networking.decodingFailed(
                data: syncData?.newData ?? [:],
                .init(sender: self)
            )
        }

        let decodedMetadata = try await ConversationMetadata(
            from: newMetadata
        )

        guard let conversation = syncData?.conversation.modifyKey(
            .metadata,
            withValue: decodedMetadata
        ) else {
            throw .Networking.typeMismatch(
                key: Conversation.SerializableKey.metadata.rawValue,
                type: type(of: decodedMetadata),
                .init(sender: self)
            )
        }

        syncData = .init(
            conversation,
            messages: syncData?.messages ?? [],
            newData: syncData?.newData ?? [:]
        )
    }

    private func synchronizeParticipants() async throws(Exception) {
        guard let participantMap = syncData?.newData[
            Conversation.SerializableKey.participants.rawValue
        ] as? [String: [String: Any]] else {
            throw .Networking.decodingFailed(
                data: syncData?.newData ?? [:],
                .init(sender: self)
            )
        }

        var updatedParticipants = [Participant]()
        for (userID, values) in participantMap {
            guard let hasDeletedConversation = values[
                Participant.SerializableKey.hasDeletedConversation.rawValue
            ] as? Bool,
                let isTyping = values[
                    Participant.SerializableKey.isTyping.rawValue
                ] as? Bool else {
                throw .Networking.decodingFailed(
                    data: values,
                    .init(sender: self)
                )
            }

            updatedParticipants.append(
                Participant(
                    userID: userID,
                    hasDeletedConversation: hasDeletedConversation,
                    isTyping: isTyping
                )
            )
        }

        guard let conversation = syncData?.conversation.modifyKey(
            .participants,
            withValue: updatedParticipants
        ) else {
            throw .Networking.typeMismatch(
                key: Conversation.SerializableKey.participants.rawValue,
                type: type(of: updatedParticipants),
                .init(sender: self)
            )
        }

        syncData = .init(
            conversation,
            messages: syncData?.messages ?? [],
            newData: syncData?.newData ?? [:]
        )
    }

    private func synchronizeReactionMetadata() async throws(Exception) {
        guard let newReactionMetadata = syncData?.newData[
            Conversation.SerializableKey.reactionMetadata.rawValue
        ] as? [[String: Any]] else {
            throw .Networking.decodingFailed(
                data: syncData?.newData ?? [:],
                .init(sender: self)
            )
        }

        let updatedReactionMetadata = try await newReactionMetadata.map {
            try await ReactionMetadata(from: $0)
        }

        guard let conversation = syncData?.conversation.modifyKey(
            .reactionMetadata,
            withValue: updatedReactionMetadata
        ) else {
            throw .Networking.typeMismatch(
                key: Conversation.SerializableKey.reactionMetadata.rawValue,
                type: type(of: updatedReactionMetadata),
                .init(sender: self)
            )
        }

        syncData = .init(
            conversation,
            messages: syncData?.messages ?? [],
            newData: syncData?.newData ?? [:]
        )
    }

    // MARK: - Auxiliary

    private func getConversationData(
        _ conversation: Conversation
    ) async throws(Exception) {
        let userInfo: [String: Any] = [
            "ConversationIDHash": conversation.id.hash,
            "ConversationIDKey": conversation.id.key,
        ]

        do {
            let currentMessages = conversation.messages?
                .uniquedByID ?? []

            syncData = try await .init(
                conversation,
                messages: currentMessages,
                newData: networking.database.getValues(
                    at: "\(NetworkPath.conversations.rawValue)/\(conversation.id.key)",
                    cacheStrategy: .disregardCache
                )
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

    private func resolveConversation(
        _ userInfo: [String: Any]
    ) async throws(Exception) -> Conversation {
        defer { syncData = nil }
        guard let syncData else {
            throw Exception(
                "Failed to resolve updated conversation.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        // Synced from network; bypasses RemotelyUpdatable.update.
        clientSession.store.upsertConversation(syncData.conversation)
        if !syncData.messages.isEmpty {
            // Synced from network; bypasses RemotelyUpdatable.update.
            clientSession.store.upsertMessages(Set(syncData.messages))
        }

        return syncData.conversation
    }

    // swiftlint:disable:next function_body_length
    private func _synchronizeConversation(
        _ conversation: Conversation
    ) async throws(Exception) -> Conversation {
        let userInfo: [String: Any] = [
            "ConversationIDHash": conversation.id.hash,
            "ConversationIDKey": conversation.id.key,
        ]

        Logger.log(
            "Synchronizing conversation with ID \(conversation.id.key).",
            domain: .conversationSync,
            sender: self
        )

        // Resolve sync data.

        do {
            try await getConversationData(conversation)
        } catch {
            self.syncData = nil
            throw error.appending(userInfo: userInfo)
        }

        // Skip message updates if current user isn't participating.

        guard let currentUserParticipant = conversation.currentUserParticipant,
              !currentUserParticipant.hasDeletedConversation else {
            Logger.log(
                .init(
                    "Skipping message retrieval for conversation in which current user is not participating or has deleted.",
                    isReportable: false,
                    userInfo: userInfo,
                    metadata: .init(sender: self)
                ),
                domain: .conversationSync
            )

            do {
                try await synchronizeData()
            } catch {
                self.syncData = nil
                throw error.appending(userInfo: userInfo)
            }

            return try await resolveConversation(userInfo)
        }

        // Resolve values for message comparison.

        guard let currentMessages = conversation
            .messages?
            .uniquedByID else {
            do {
                try await conversation.resolveMessages()
                syncData = .init(
                    conversation,
                    messages: conversation
                        .messages?
                        .uniquedByID ?? [],
                    newData: syncData?.newData ?? [:]
                )

                return try await _synchronizeConversation(conversation)
            } catch {
                self.syncData = nil
                throw error.appending(userInfo: userInfo)
            }
        }

        guard let syncData else {
            syncData = nil
            throw Exception(
                "Failed to resolve current sync data.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        let messageIDs: [String] = if let map = syncData.newData[
            Conversation.SerializableKey.messages.rawValue
        ] as? [String: Any] {
            map.keys.sorted()
        } else {
            []
        }

        let currentMessageIDs = Set(currentMessages.map(\.id))
        var filteredMessageIDs = messageIDs.filter { !currentMessageIDs.contains($0) }
        if filteredMessageIDs.isEmpty {
            let existingMessageIDs = Set(conversation.messageIDs)
            filteredMessageIDs = messageIDs.filter { !existingMessageIDs.contains($0) }
        }

        // Update messages if necessary.

        filteredMessageIDs = filteredMessageIDs.unique
        guard filteredMessageIDs.isEmpty else {
            do {
                try await synchronizeMessages(filteredMessageIDs)
                try await synchronizeData()
            } catch {
                self.syncData = nil
                throw error.appending(userInfo: userInfo)
            }

            return try await resolveConversation(userInfo)
        }

        // If no messages to update, synchronize metadata until hashes are sufficiently mismatched.

        do {
            try await synchronizeData()
        } catch {
            self.syncData = nil
            throw error.appending(userInfo: userInfo)
        }

        guard self
            .syncData?
            .conversation
            .encodedHash == conversation
            .encodedHash else { return try await resolveConversation(userInfo) }

        // If metadata ostensibly didn't need an update, reload select or all messages.

        do {
            try await synchronizeMessages(
                messageIDs,
                lastTenOnly: true
            )
        } catch {
            self.syncData = nil
            throw error.appending(userInfo: userInfo)
        }

        // If reloading last 10 messages didn't help, reload all messages.

        if self.syncData?.conversation.encodedHash == conversation.encodedHash {
            Logger.log(
                .init(
                    "Resolving all messages to fully synchronize conversation.",
                    isReportable: false,
                    userInfo: userInfo,
                    metadata: .init(sender: self)
                ),
                domain: .conversationSync
            )

            Self.recentlyFailedSyncRecords.projectedValue.withValue {
                $0 = $0.filter { !$0.isExpired }

                let previousAttempt = $0.first(
                    where: { $0.conversationIDKey == conversation.id.key }
                )?.attempt ?? 0

                $0.remove(.init(conversationIDKey: conversation.id.key))
                $0.insert(.init(
                    conversationIDKey: conversation.id.key,
                    attempt: previousAttempt + 1
                ))
            }

            do {
                try await synchronizeMessages(messageIDs)
            } catch {
                self.syncData = nil
                throw error.appending(userInfo: userInfo)
            }
        }

        return try await resolveConversation(userInfo)
    }
}

// swiftlint:enable file_length type_body_length
