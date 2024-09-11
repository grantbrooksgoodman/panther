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
                users: users
            ))
        }
    }

    // MARK: - Update Value

    public func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: Networking
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        guard updatableKeys.contains(key) else {
            return .failure(.notUpdatable(key: key, [self, #file, #function, #line]))
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
            return .failure(.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        let conversationKeyPath = "\(networking.config.paths.conversations)/\(id.key)/"
        let valueKeyPath = conversationKeyPath + key.rawValue

        if key == .messages,
           let messages = value as? [Message] {
            let messageIDs = messages.map(\.id).isBangQualifiedEmpty ? Array.bangQualifiedEmpty : messages.map(\.id)
            if let exception = await networking.database.setValue(messageIDs.unique, forKey: valueKeyPath) {
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
            return .failure(.notSerialized(data: [key.rawValue: value], [self, #file, #function, #line]))
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

        return .success(updated)
    }

    // MARK: - Auxiliary

    private func updateIDHash(_ conversation: Conversation) -> Conversation {
        .init(
            .init(key: conversation.id.key, hash: conversation.encodedHash),
            messageIDs: conversation.messageIDs,
            messages: conversation.messages,
            metadata: conversation.metadata,
            participants: conversation.participants,
            users: conversation.users
        )
    }

    /// It's optimal to set `isTyping` to `false` in the same call as appending messages during a send operation so the conversation hash doesn't need to be recomputed twice.
    private func updateIsTyping(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: Networking

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
            users: conversation.users
        ))

        if let exception = await networking.database.setValue(
            updatedConversation.participants.map(\.encoded),
            forKey: "\(networking.config.paths.conversations)/\(updatedConversation.id.key)/\(SerializationKeys.participants.rawValue)"
        ) {
            return .failure(exception)
        }

        return .success(updatedConversation)
    }
}
