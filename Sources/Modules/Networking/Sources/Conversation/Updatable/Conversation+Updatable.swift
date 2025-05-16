//
//  Conversation+Updatable.swift
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

extension Conversation: Updatable {
    // MARK: - Type Aliases

    public typealias SerializationKey = Conversation.SerializationKeys
    public typealias U = Conversation

    // MARK: - Properties

    public var updatableKeys: [SerializationKeys] {
        [
            .messages,
            .metadata,
            .participants,
            .reactionMetadata,
        ]
    }

    // MARK: - Modify Key

    public func modifyKey(_ key: SerializationKeys, withValue value: Any) -> Conversation? {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        switch key {
        case .encodedHash,
             .id:
            return nil

        case .messages:
            guard let value = value as? [Message] else { return nil }
            return updateIDHash(.init(
                id,
                messageIDs: value.map(\.id).unique,
                messages: value.uniquedByID,
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata,
                users: users
            ))

        case .metadata:
            guard let value = value as? ConversationMetadata else { return nil }
            return updateIDHash(.init(
                id,
                messageIDs: messageIDs,
                messages: messages,
                metadata: value,
                participants: participants,
                reactionMetadata: reactionMetadata,
                users: users
            ))

        case .participants:
            guard let value = value as? [Participant] else { return nil }
            return updateIDHash(.init(
                id,
                messageIDs: messageIDs,
                messages: messages,
                metadata: metadata,
                participants: value,
                reactionMetadata: reactionMetadata,
                users: users
            ))

        case .reactionMetadata:
            guard let value = value as? [ReactionMetadata] else { return nil }
            return updateIDHash(.init(
                id,
                messageIDs: messageIDs,
                messages: messages,
                metadata: metadata,
                participants: participants,
                reactionMetadata: value.allSatisfy { $0 == .empty } || value.isEmpty ? nil : value,
                users: users
            ))
        }
    }

    // MARK: - Update Value

    public func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        guard updatableKeys.contains(key) else {
            return .failure(.Networking.notUpdatable(key: key, [self, #file, #function, #line]))
        }

        if let exception = await setUsers(forceUpdate: true) {
            return .failure(exception)
        }

        guard var users else {
            return .failure(.init(
                "Failed to set users on conversation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        guard var updated = modifyKey(key, withValue: value) else {
            return .failure(.Networking.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(id.key)/"
        let valueKeyPath = conversationKeyPath + key.rawValue

        if key == .messages,
           let messageIDs = (value as? [Message])?.map(\.id) {
            if let exception = await addMessageIDs(messageIDs) {
                return .failure(exception)
            }

            let updateIsTypingResult = await updateIsTyping(updated)
            switch updateIsTypingResult {
            case let .success(updatedConversation): updated = updatedConversation
            case let .failure(exception): return .failure(exception)
            }
        } else if let serializable = value as? any Serializable {
            if let exception = await networking.database.setValue(serializable.encoded, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if let serializable = value as? [any Serializable] {
            if let exception = await networking.database.setValue(serializable.map { $0.encoded }, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if networking.database.isEncodable(value) {
            if let exception = await networking.database.setValue(value, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else {
            return .failure(.Networking.notSerialized(data: [key.rawValue: value], [self, #file, #function, #line]))
        }

        guard updated.encodedHash != encodedHash else {
            return .success(updated)
        }

        let hashPath = conversationKeyPath + SerializationKeys.encodedHash.rawValue
        if let exception = await networking.database.setValue(updated.encodedHash, forKey: hashPath) {
            return .failure(exception)
        }

        if let currentUser = userSession.currentUser {
            users.append(currentUser)
        }

        for user in users {
            guard var conversationIDs = user.conversationIDs,
                  let index = conversationIDs.firstIndex(where: { $0.key == updated.id.key }) else { continue }

            conversationIDs.removeAll(where: { $0.key == updated.id.key })
            conversationIDs.insert(updated.id, at: index)

            let updateValueResult = await user.updateValue(conversationIDs, forKey: .conversationIDs)

            switch updateValueResult {
            case let .failure(exception):
                return .failure(exception)

            default: ()
            }
        }

        // NIT: Fixes looping updates when updating read receipts, but unsure of efficacy.
        networking.conversationService.archive.addValue(updated)
        return .success(updated)
    }

    // MARK: - Auxiliary

    /// Ensures updates take into account any messages sent during execution of `updateValue` logic.
    /// We disregard modification of the local value, since this scenario should trigger a latent call to `ConversationsPageViewObserver.updateConversations()`.
    private func addMessageIDs(_ messageIDs: [String]) async -> Exception? {
        @Dependency(\.networking) var networking: NetworkServices

        var newMessageIDs = messageIDs

        let messagesKeyPath = "\(NetworkPath.conversations.rawValue)/\(id.key)/\(Conversation.SerializationKeys.messages.rawValue)"
        let getValuesResult = await networking.database.getValues(at: messagesKeyPath, cacheStrategy: .disregardCache)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .Networking.typecastFailed("array", metadata: [self, #file, #function, #line])
            }

            newMessageIDs += array

        case let .failure(exception):
            return exception
        }

        if let exception = await networking.database.setValue(
            newMessageIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : newMessageIDs.unique,
            forKey: messagesKeyPath
        ) {
            return exception
        }

        return nil
    }

    private func updateIDHash(_ conversation: Conversation) -> Conversation {
        .init(
            .init(key: conversation.id.key, hash: conversation.encodedHash),
            messageIDs: conversation.messageIDs,
            messages: conversation.messages,
            metadata: conversation.metadata,
            participants: conversation.participants,
            reactionMetadata: conversation.reactionMetadata,
            users: conversation.users
        )
    }

    /// It's optimal to set `isTyping` to `false` in the same call as appending messages during a send operation so the conversation hash doesn't need to be recomputed twice.
    private func updateIsTyping(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: NetworkServices

        guard let currentUserParticipant = conversation.currentUserParticipant else {
            return .failure(.init(
                "Failed to resolve current user participant.",
                metadata: [self, #file, #function, #line]
            ))
        }

        var newParticipants = [Participant]()
        newParticipants = participants.filter { $0 != currentUserParticipant }
        newParticipants.append(.init(
            userID: currentUserParticipant.userID,
            hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
            isTyping: false
        ))

        // TODO: Audit whether or not it is necessary to update the ID hash here.
        let updatedConversation = updateIDHash(.init(
            conversation.id,
            messageIDs: conversation.messageIDs,
            messages: conversation.messages,
            metadata: conversation.metadata,
            participants: newParticipants,
            reactionMetadata: conversation.reactionMetadata,
            users: conversation.users
        ))

        if let exception = await networking.database.setValue(
            updatedConversation.participants.map(\.encoded),
            forKey: "\(NetworkPath.conversations.rawValue)/\(updatedConversation.id.key)/\(SerializationKeys.participants.rawValue)"
        ) {
            return .failure(exception)
        }

        return .success(updatedConversation)
    }
}
