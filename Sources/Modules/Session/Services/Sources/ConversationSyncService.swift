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

final class ConversationSyncService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    @LockIsolated private static var inFlightTasks = [String: Task<Callback<Conversation, Exception>, Never>]()
    @LockIsolated private static var _recentlyFailedSyncRecords: Set<SynchronizationRecord> = []

    @LockIsolated private var _syncData: ConversationSyncData = .empty

    // MARK: - Computed Properties

    private var recentlyFailedSyncRecords: Set<SynchronizationRecord> {
        get { ConversationSyncService._recentlyFailedSyncRecords.filter { !$0.isExpired } }
        set { ConversationSyncService._recentlyFailedSyncRecords = newValue }
    }

    private var syncData: ConversationSyncData? {
        get { _syncData == .empty ? nil : _syncData }
        set { _syncData = newValue ?? .empty }
    }

    // MARK: - Synchronization

    func synchronizeConversation(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        if let existingTask = ConversationSyncService.inFlightTasks[conversation.id.key] {
            return await existingTask.value
        }

        guard !recentlyFailedSyncRecords.contains(where: {
            $0.conversationID == conversation.id
        }) else { return .success(conversation) }

        let task = Task { [weak self] () -> Callback<Conversation, Exception> in
            guard let self else {
                ConversationSyncService.inFlightTasks[conversation.id.key] = nil
                return .failure(.init(
                    "Service has been deallocated.",
                    metadata: .init(sender: ConversationSyncService.self)
                ))
            }

            let synchronizeConversationResult = await self._synchronizeConversation(conversation)
            ConversationSyncService.inFlightTasks[conversation.id.key] = nil
            return synchronizeConversationResult
        }

        ConversationSyncService.inFlightTasks[conversation.id.key] = task
        return await task.value
    }

    // MARK: - Auxiliary

    private func synchronizeActivities() async -> Exception? {
        guard let newActivities = syncData?.newData[
            Conversation.SerializationKeys.activities.rawValue
        ] as? [[String: Any]] else {
            return .Networking.decodingFailed(
                data: syncData?.newData ?? [:],
                .init(sender: self)
            )
        }

        var updatedActivities = [Activity]()

        for activity in newActivities {
            let decodeResult = await Activity.decode(from: activity)

            switch decodeResult {
            case let .success(decodedActivity): updatedActivities.append(decodedActivity)
            case let .failure(exception): return exception
            }
        }

        guard !updatedActivities.isEmpty,
              updatedActivities.count == newActivities.count else {
            return .init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        guard let conversation = syncData?.conversation.modifyKey(
            .activities,
            withValue: updatedActivities
        ) else {
            return .Networking.typeMismatch(
                key: Conversation.SerializationKeys.activities.rawValue,
                .init(sender: self)
            )
        }

        syncData = .init(
            conversation,
            newData: syncData?.newData ?? [:]
        )

        return nil
    }

    // swiftlint:disable:next function_body_length
    private func _synchronizeConversation(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let userInfo: [String: Any] = [
            "ConversationIDHash": conversation.id.hash,
            "ConversationIDKey": conversation.id.key,
        ]

        func resolveConversation() -> Callback<Conversation, Exception> {
            defer { syncData = nil }
            guard let conversation = syncData?.conversation else {
                return .failure(.init(
                    "Failed to resolve updated conversation.",
                    metadata: .init(sender: self)
                ).appending(userInfo: userInfo))
            }

            return .success(conversation.withHydratedMessages)
        }

        func getConversationData() async -> Exception? {
            let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(conversation.id.key)"
            let getValuesResult = await networking.database.getValues(at: conversationKeyPath, cacheStrategy: .disregardCache)

            switch getValuesResult {
            case let .success(values):
                guard let newData = values as? [String: Any] else {
                    return .Networking.typecastFailed(
                        "dictionary",
                        metadata: .init(sender: self)
                    ).appending(userInfo: userInfo)
                }

                syncData = .init(conversation, newData: newData)
                return nil

            case let .failure(exception):
                return exception.appending(userInfo: userInfo)
            }
        }

        Logger.log(
            "Synchronizing conversation with ID \(conversation.id.key).",
            domain: .conversation,
            sender: self
        )

        guard let currentUserParticipant = conversation.currentUserParticipant,
              !currentUserParticipant.hasDeletedConversation else {
            Logger.log(
                .init(
                    "Skipping message retrieval for conversation in which current user is not participating or has deleted.",
                    isReportable: false,
                    userInfo: userInfo,
                    metadata: .init(sender: self)
                ),
                domain: .conversation
            )

            if let exception = await getConversationData() {
                return .failure(exception.appending(userInfo: userInfo))
            }

            if let exception = await synchronizeData() {
                return .failure(exception.appending(userInfo: userInfo))
            }

            return resolveConversation()
        }

        guard let currentMessages = conversation
            .messages?
            .filteringSystemMessages
            .uniquedByID else {
            if let exception = await conversation.setMessages() {
                return .failure(exception.appending(userInfo: userInfo))
            }

            return await _synchronizeConversation(conversation)
        }

        if let exception = await getConversationData() {
            return .failure(exception.appending(userInfo: userInfo))
        }

        guard let syncData else {
            self.syncData = nil
            return .failure(.init(
                "Failed to resolve current sync data.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo))
        }

        guard let messageIDs = syncData.newData[Conversation.SerializationKeys.messages.rawValue] as? [String] else {
            self.syncData = nil
            return .failure(.Networking.decodingFailed(
                data: syncData.newData,
                .init(sender: self)
            ).appending(userInfo: userInfo))
        }

        var filteredMessageIDs = messageIDs.filter { !currentMessages.map(\.id).contains($0) }
        if filteredMessageIDs.isEmpty {
            filteredMessageIDs = messageIDs.filter { !conversation.messageIDs.contains($0) }
        }

        filteredMessageIDs = filteredMessageIDs.unique
        guard !filteredMessageIDs.isEmpty else {
            if let exception = await synchronizeData() {
                self.syncData = nil
                return .failure(exception.appending(userInfo: userInfo))
            }

            // If metadata ostensibly didn't need an update, reload select or all messages.
            guard let syncData = self.syncData,
                  syncData.conversation.encodedHash != conversation.encodedHash else {
                if let exception = await synchronizeMessages(messageIDs, lastTenOnly: true) {
                    self.syncData = nil
                    return .failure(exception.appending(userInfo: userInfo))
                }

                guard let syncData = self.syncData,
                      syncData.conversation.encodedHash != conversation.encodedHash else {
                    Logger.log(
                        .init(
                            "Resolving all messages to fully synchronize conversation.",
                            isReportable: false,
                            userInfo: userInfo,
                            metadata: .init(sender: self)
                        ),
                        domain: .conversation
                    )

                    recentlyFailedSyncRecords.insert(.init(conversation.id))
                    if let exception = await synchronizeMessages(messageIDs) {
                        self.syncData = nil
                        return .failure(exception.appending(userInfo: userInfo))
                    }

                    return resolveConversation()
                }

                return resolveConversation()
            }

            return resolveConversation()
        }

        if let exception = await synchronizeMessages(filteredMessageIDs) {
            self.syncData = nil
            return .failure(exception.appending(userInfo: userInfo))
        }

        if let exception = await synchronizeData() {
            self.syncData = nil
            return .failure(exception.appending(userInfo: userInfo))
        }

        return resolveConversation()
    }

    private func synchronizeData() async -> Exception? {
        if let exception = await synchronizeActivities() {
            return exception
        }

        if let exception = await synchronizeParticipants() {
            return exception
        }

        if let exception = await synchronizeMetadata() {
            return exception
        }

        if let exception = await synchronizeReactionMetadata() {
            return exception
        }

        return synchronizeHash()
    }

    private func synchronizeHash() -> Exception? {
        guard let syncData else {
            return .Networking.decodingFailed(
                data: syncData?.newData ?? [:],
                .init(sender: self)
            )
        }

        self.syncData = .init(
            .init(
                .init(
                    key: syncData.conversation.id.key,
                    hash: syncData.conversation.encodedHash
                ),
                activities: syncData.conversation.activities,
                messageIDs: syncData.conversation.messageIDs,
                messages: syncData.conversation.messages,
                metadata: syncData.conversation.metadata,
                participants: syncData.conversation.participants,
                reactionMetadata: syncData.conversation.reactionMetadata,
                users: syncData.conversation.users
            ),
            newData: syncData.newData
        )

        return nil
    }

    private func synchronizeMessages(_ messageIDs: [String], lastTenOnly: Bool = false) async -> Exception? {
        guard let conversation = syncData?.conversation else {
            return .init("Failed to resolve conversation in sync data.", metadata: .init(sender: self))
        }

        var messageIDs = messageIDs
        if lastTenOnly,
           messageIDs.count >= 10 {
            messageIDs = Array(messageIDs.reversed()[0 ... 9])
        }

        let getMessagesResult = await networking.messageService.getMessages(ids: messageIDs)

        switch getMessagesResult {
        case let .success(messages):
            let updatedMessages = ((conversation.messages ?? []) + messages)
                .filteringSystemMessages
                .uniquedByID
                .sortedByAscendingSentDate
            guard let conversation = conversation.modifyKey(.messages, withValue: updatedMessages) else {
                return .Networking.typeMismatch(
                    key: Conversation.SerializationKeys.messages,
                    .init(sender: self)
                )
            }

            if let exception = await updateHash(conversation) {
                return exception
            }

            syncData = .init(conversation, newData: syncData?.newData ?? [:])
            return synchronizeHash()

        case let .failure(exception):
            return exception
        }
    }

    private func synchronizeMetadata() async -> Exception? {
        guard let newMetadata = syncData?.newData[Conversation.SerializationKeys.metadata.rawValue] as? [String: Any] else {
            return .Networking.decodingFailed(data: syncData?.newData ?? [:], .init(sender: self))
        }

        let decodeResult = await ConversationMetadata.decode(from: newMetadata)

        switch decodeResult {
        case let .success(decodedMetadata):
            guard let conversation = syncData?.conversation.modifyKey(.metadata, withValue: decodedMetadata) else {
                return .Networking.typeMismatch(
                    key: Conversation.SerializationKeys.metadata.rawValue,
                    .init(sender: self)
                )
            }

            syncData = .init(conversation, newData: syncData?.newData ?? [:])
            return nil

        case let .failure(exception):
            return exception
        }
    }

    private func synchronizeParticipants() async -> Exception? {
        guard let newParticipants = syncData?.newData[Conversation.SerializationKeys.participants.rawValue] as? [String] else {
            return .Networking.decodingFailed(data: syncData?.newData ?? [:], .init(sender: self))
        }

        var updatedParticipants = [Participant]()

        for participant in newParticipants {
            let decodeResult = await Participant.decode(from: participant)

            switch decodeResult {
            case let .success(decodedParticipant):
                updatedParticipants.append(decodedParticipant)

            case let .failure(exception):
                return exception
            }
        }

        guard !updatedParticipants.isEmpty,
              updatedParticipants.count == newParticipants.count else {
            return .init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        guard let conversation = syncData?.conversation.modifyKey(.participants, withValue: updatedParticipants) else {
            return .Networking.typeMismatch(
                key: Conversation.SerializationKeys.participants.rawValue,
                .init(sender: self)
            )
        }

        syncData = .init(conversation, newData: syncData?.newData ?? [:])
        return nil
    }

    private func synchronizeReactionMetadata() async -> Exception? {
        guard let newReactionMetadata = syncData?.newData[Conversation.SerializationKeys.reactionMetadata.rawValue] as? [[String: Any]] else {
            return .Networking.decodingFailed(data: syncData?.newData ?? [:], .init(sender: self))
        }

        var updatedReactionMetadata = [ReactionMetadata]()

        for reactionMetadata in newReactionMetadata {
            let decodeResult = await ReactionMetadata.decode(from: reactionMetadata)

            switch decodeResult {
            case let .success(decodedReactionMetadata):
                updatedReactionMetadata.append(decodedReactionMetadata)

            case let .failure(exception):
                return exception
            }
        }

        guard !updatedReactionMetadata.isEmpty,
              updatedReactionMetadata.count == newReactionMetadata.count else {
            return .init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        guard let conversation = syncData?.conversation.modifyKey(.reactionMetadata, withValue: updatedReactionMetadata) else {
            return .Networking.typeMismatch(
                key: Conversation.SerializationKeys.reactionMetadata.rawValue,
                .init(sender: self)
            )
        }

        syncData = .init(conversation, newData: syncData?.newData ?? [:])
        return nil
    }

    private func updateHash(_ conversation: Conversation) async -> Exception? {
        // TODO: Audit efficacy of this with multiple running instances.
        if let currentUser,
           var conversationIDs = currentUser.conversationIDs,
           let index = conversationIDs.firstIndex(where: {
               $0.key == conversation.id.key
           }) {
            conversationIDs.removeAll(where: { $0.key == conversation.id.key })
            conversationIDs.insert(
                .init(
                    key: conversation.id.key,
                    hash: conversation.encodedHash
                ),
                at: index
            )

            let updateValueResult = await currentUser.updateValue(
                conversationIDs,
                forKey: .conversationIDs
            )

            switch updateValueResult {
            case let .failure(exception): return exception
            default: ()
            }
        }

        let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(conversation.id.key)/"
        let hashPath = conversationKeyPath + Conversation.SerializationKeys.encodedHash.rawValue
        return await networking.database.setValue(
            conversation.encodedHash,
            forKey: hashPath
        )
    }
}

// swiftlint:enable file_length type_body_length
