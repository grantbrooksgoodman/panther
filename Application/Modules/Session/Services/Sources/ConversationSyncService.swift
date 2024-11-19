//
//  ConversationSyncService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public final class ConversationSyncService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    private var syncData: ConversationSyncData?

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
                    metadata: [self, #file, #function, #line]
                ).appending(extraParams: commonParams))
            }

            return .success(conversation)
        }

        Logger.log(
            "Synchronizing conversation with ID \(conversation.id.key).",
            domain: .conversation,
            metadata: [self, #file, #function, #line]
        )

        guard let currentUserParticipant = conversation.currentUserParticipant,
              !currentUserParticipant.hasDeletedConversation else {
            Logger.log(
                .init(
                    "Skipping message retrieval for conversation in which current user is not participating or has deleted.",
                    extraParams: commonParams,
                    metadata: [self, #file, #function, #line]
                ),
                domain: .conversation
            )

            if let exception = await synchronizeData() {
                return .failure(exception.appending(extraParams: commonParams))
            }

            return resolveConversation()
        }

        guard let currentMessages = conversation.messages?.uniquedByID else {
            if let exception = await conversation.setMessages() {
                return .failure(exception.appending(extraParams: commonParams))
            }

            return await synchronizeConversation(conversation)
        }

        let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(conversation.id.key)"
        let getValuesResult = await networking.database.getValues(at: conversationKeyPath, cacheStrategy: .disregardCache)

        switch getValuesResult {
        case let .success(values):
            guard let newData = values as? [String: Any] else {
                return .failure(
                    .typecastFailed("dictionary", metadata: [self, #file, #function, #line]).appending(extraParams: commonParams)
                )
            }

            syncData = .init(conversation, newData: newData)

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }

        guard let syncData else {
            self.syncData = nil
            return .failure(.init(
                "Failed to resolve current sync data.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        guard let messageIDs = syncData.newData[Conversation.SerializationKeys.messages.rawValue] as? [String] else {
            self.syncData = nil
            return .failure(.decodingFailed(
                data: syncData.newData,
                [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        var filteredMessageIDs = messageIDs.filter { !currentMessages.map(\.id).contains($0) }
        if messageIDs.isEmpty {
            filteredMessageIDs = messageIDs.filter { !conversation.messageIDs.contains($0) }
        }

        filteredMessageIDs = filteredMessageIDs.unique
        guard !filteredMessageIDs.isEmpty else {
            if let exception = await synchronizeData() {
                self.syncData = nil
                return .failure(exception.appending(extraParams: commonParams))
            }

            // If metadata ostensibly didn't need an update, reload select or all messages.
            guard let syncData = self.syncData,
                  syncData.conversation.encodedHash != conversation.encodedHash else {
                if let exception = await synchronizeMessages(messageIDs, lastTenOnly: true) {
                    self.syncData = nil
                    return .failure(exception.appending(extraParams: commonParams))
                }

                guard let syncData = self.syncData,
                      syncData.conversation.encodedHash != conversation.encodedHash else {
                    Logger.log(
                        .init(
                            "Resolving all messages to fully synchronize conversation.",
                            extraParams: commonParams,
                            metadata: [self, #file, #function, #line]
                        ),
                        domain: .conversation
                    )

                    if let exception = await synchronizeMessages(messageIDs) {
                        self.syncData = nil
                        return .failure(exception.appending(extraParams: commonParams))
                    }

                    return resolveConversation()
                }

                return resolveConversation()
            }

            return resolveConversation()
        }

        if let exception = await synchronizeMessages(filteredMessageIDs) {
            self.syncData = nil
            return .failure(exception.appending(extraParams: commonParams))
        }

        if let exception = await synchronizeData() {
            self.syncData = nil
            return .failure(exception.appending(extraParams: commonParams))
        }

        return resolveConversation()
    }

    private func synchronizeData() async -> Exception? {
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
            return .decodingFailed(data: syncData?.newData ?? [:], [self, #file, #function, #line])
        }

        self.syncData = .init(.init(
            .init(key: syncData.conversation.id.key, hash: newHash),
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
            return .init("Failed to resolve conversation in sync data.", metadata: [self, #file, #function, #line])
        }

        var messageIDs = messageIDs
        if lastTenOnly,
           messageIDs.count >= 10 {
            messageIDs = Array(messageIDs.reversed()[0 ... 9])
        }

        let getMessagesResult = await networking.messageService.getMessages(ids: messageIDs)

        switch getMessagesResult {
        case let .success(messages):
            let updatedMessages = ((conversation.messages ?? []) + messages).uniquedByID.sortedByAscendingSentDate
            guard let conversation = conversation.modifyKey(.messages, withValue: updatedMessages) else {
                return .typeMismatch(key: Conversation.SerializationKeys.messages, [self, #file, #function, #line])
            }

            syncData = .init(conversation, newData: syncData?.newData ?? [:])
            return synchronizeHash()

        case let .failure(exception):
            return exception
        }
    }

    private func synchronizeMetadata() async -> Exception? {
        guard let newMetadata = syncData?.newData[Conversation.SerializationKeys.metadata.rawValue] as? [String: Any] else {
            return .decodingFailed(data: syncData?.newData ?? [:], [self, #file, #function, #line])
        }

        let decodeResult = await ConversationMetadata.decode(from: newMetadata)

        switch decodeResult {
        case let .success(decodedMetadata):
            guard let conversation = syncData?.conversation.modifyKey(.metadata, withValue: decodedMetadata) else {
                return .typeMismatch(
                    key: Conversation.SerializationKeys.metadata.rawValue,
                    [self, #file, #function, #line]
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
            return .decodingFailed(data: syncData?.newData ?? [:], [self, #file, #function, #line])
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
                metadata: [self, #file, #function, #line]
            )
        }

        guard let conversation = syncData?.conversation.modifyKey(.participants, withValue: updatedParticipants) else {
            return .typeMismatch(
                key: Conversation.SerializationKeys.participants.rawValue,
                [self, #file, #function, #line]
            )
        }

        syncData = .init(conversation, newData: syncData?.newData ?? [:])
        return nil
    }

    private func synchronizeReactionMetadata() async -> Exception? {
        guard let newReactionMetadata = syncData?.newData[Conversation.SerializationKeys.reactionMetadata.rawValue] as? [[String: Any]] else {
            return .decodingFailed(data: syncData?.newData ?? [:], [self, #file, #function, #line])
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
                metadata: [self, #file, #function, #line]
            )
        }

        guard let conversation = syncData?.conversation.modifyKey(.reactionMetadata, withValue: updatedReactionMetadata) else {
            return .typeMismatch(
                key: Conversation.SerializationKeys.reactionMetadata.rawValue,
                [self, #file, #function, #line]
            )
        }

        syncData = .init(conversation, newData: syncData?.newData ?? [:])
        return nil
    }
}
