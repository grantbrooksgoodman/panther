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

public final class ConversationSyncService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    @LockIsolated private var _syncData: ConversationSyncData = .empty

    // MARK: - Computed Properties

    private var syncData: ConversationSyncData? {
        get { _syncData == .empty ? nil : _syncData }
        set { _syncData = newValue ?? .empty }
    }

    // MARK: - Synchronization

    // swiftlint:disable:next function_body_length
    public func synchronizeConversation(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let commonParams: [String: Any] = [
            "ConversationIDHash": conversation.id.hash,
            "ConversationIDKey": conversation.id.key,
        ]

        func resolveConversation() -> Callback<Conversation, Exception> {
            defer { syncData = nil }
            guard let conversation = syncData?.conversation else {
                return .failure(.init(
                    "Failed to resolve updated conversation.",
                    metadata: .init(sender: self)
                ).appending(userInfo: commonParams))
            }

            return .success(conversation)
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
                    ).appending(userInfo: commonParams)
                }

                syncData = .init(conversation, newData: newData)
                return nil

            case let .failure(exception):
                return exception.appending(userInfo: commonParams)
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
                    userInfo: commonParams,
                    metadata: .init(sender: self)
                ),
                domain: .conversation
            )

            if let exception = await getConversationData() {
                return .failure(exception.appending(userInfo: commonParams))
            }

            if let exception = await synchronizeData() {
                return .failure(exception.appending(userInfo: commonParams))
            }

            return resolveConversation()
        }

        guard let currentMessages = conversation.messages?.uniquedByID else {
            if let exception = await conversation.setMessages() {
                return .failure(exception.appending(userInfo: commonParams))
            }

            return await synchronizeConversation(conversation)
        }

        if let exception = await getConversationData() {
            return .failure(exception.appending(userInfo: commonParams))
        }

        guard let syncData else {
            self.syncData = nil
            return .failure(.init(
                "Failed to resolve current sync data.",
                metadata: .init(sender: self)
            ).appending(userInfo: commonParams))
        }

        guard let messageIDs = syncData.newData[Conversation.SerializationKeys.messages.rawValue] as? [String] else {
            self.syncData = nil
            return .failure(.Networking.decodingFailed(
                data: syncData.newData,
                .init(sender: self)
            ).appending(userInfo: commonParams))
        }

        var filteredMessageIDs = messageIDs.filter { !currentMessages.map(\.id).contains($0) }
        if filteredMessageIDs.isEmpty {
            filteredMessageIDs = messageIDs.filter { !conversation.messageIDs.contains($0) }
        }

        filteredMessageIDs = filteredMessageIDs.unique
        guard !filteredMessageIDs.isEmpty else {
            if let exception = await synchronizeData() {
                self.syncData = nil
                return .failure(exception.appending(userInfo: commonParams))
            }

            // If metadata ostensibly didn't need an update, reload select or all messages.
            guard let syncData = self.syncData,
                  syncData.conversation.encodedHash != conversation.encodedHash else {
                if let exception = await synchronizeMessages(messageIDs, lastTenOnly: true) {
                    self.syncData = nil
                    return .failure(exception.appending(userInfo: commonParams))
                }

                guard let syncData = self.syncData,
                      syncData.conversation.encodedHash != conversation.encodedHash else {
                    Logger.log(
                        .init(
                            "Resolving all messages to fully synchronize conversation.",
                            isReportable: false,
                            userInfo: commonParams,
                            metadata: .init(sender: self)
                        ),
                        domain: .conversation
                    )

                    if let exception = await synchronizeMessages(messageIDs) {
                        self.syncData = nil
                        return .failure(exception.appending(userInfo: commonParams))
                    }

                    return resolveConversation()
                }

                return resolveConversation()
            }

            return resolveConversation()
        }

        if let exception = await synchronizeMessages(filteredMessageIDs) {
            self.syncData = nil
            return .failure(exception.appending(userInfo: commonParams))
        }

        if let exception = await synchronizeData() {
            self.syncData = nil
            return .failure(exception.appending(userInfo: commonParams))
        }

        return resolveConversation()
    }

    // MARK: - Auxiliary

    private func synchronizeActivities() async -> Exception? {
        guard let newActivities = syncData?.newData[Conversation.SerializationKeys.activities.rawValue] as? [[String: Any]] else {
            return .Networking.decodingFailed(data: syncData?.newData ?? [:], .init(sender: self))
        }

        var updatedActivities = [Activity]()

        for activity in newActivities {
            let decodeResult = await Activity.decode(from: activity)

            switch decodeResult {
            case let .success(decodedActivity):
                updatedActivities.append(decodedActivity)

            case let .failure(exception):
                return exception
            }
        }

        guard !updatedActivities.isEmpty,
              updatedActivities.count == newActivities.count else {
            return .init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        guard let conversation = syncData?.conversation.modifyKey(.activities, withValue: updatedActivities) else {
            return .Networking.typeMismatch(
                key: Conversation.SerializationKeys.activities.rawValue,
                .init(sender: self)
            )
        }

        syncData = .init(conversation, newData: syncData?.newData ?? [:])
        return nil
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
        guard let syncData,
              let newHash = syncData.newData[Conversation.SerializationKeys.encodedHash.rawValue] as? String else {
            return .Networking.decodingFailed(data: syncData?.newData ?? [:], .init(sender: self))
        }

        self.syncData = .init(.init(
            .init(key: syncData.conversation.id.key, hash: newHash),
            activities: syncData.conversation.activities,
            messageIDs: syncData.conversation.messageIDs,
            messages: syncData.conversation.messages,
            metadata: syncData.conversation.metadata,
            participants: syncData.conversation.participants,
            reactionMetadata: syncData.conversation.reactionMetadata,
            users: syncData.conversation.users
        ), newData: syncData.newData)
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
            let updatedMessages = ((conversation.messages ?? []) + messages).uniquedByID
            guard let conversation = conversation.modifyKey(
                .messages,
                withValue: updatedMessages.hydrated(with: conversation.activities)
            ) else {
                return .Networking.typeMismatch(
                    key: Conversation.SerializationKeys.messages,
                    .init(sender: self)
                )
            }

            let updateHashResult = await updateHash(conversation)

            switch updateHashResult {
            case let .success(conversation):
                syncData = .init(conversation, newData: syncData?.newData ?? [:])
                return synchronizeHash()

            case let .failure(exception):
                return exception
            }

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

    private func updateHash(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        if let exception = await conversation.setUsers(forceUpdate: true) {
            return .failure(exception)
        }

        guard var users = conversation.users else {
            return .failure(.init(
                "Failed to set users on conversation.",
                metadata: .init(sender: self)
            ))
        }

        if let currentUser {
            users.append(currentUser)
        }

        let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(conversation.id.key)/"
        let hashPath = conversationKeyPath + Conversation.SerializationKeys.encodedHash.rawValue
        if let exception = await networking.database.setValue(
            conversation.encodedHash,
            forKey: hashPath
        ) {
            return .failure(exception)
        }

        for user in users {
            guard var conversationIDs = user.conversationIDs,
                  let index = conversationIDs.firstIndex(where: { $0.key == conversation.id.key }) else { continue }

            conversationIDs.removeAll(where: { $0.key == conversation.id.key })
            conversationIDs.insert(conversation.id, at: index)

            let updateValueResult = await user.updateValue(conversationIDs, forKey: .conversationIDs)

            switch updateValueResult {
            case let .failure(exception):
                return .failure(exception)

            default: ()
            }
        }

        return .success(conversation)
    }
}

// swiftlint:enable file_length type_body_length
