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

    typealias SerializationKey = Conversation.SerializationKeys
    typealias U = Conversation

    // MARK: - Properties

    var updatableKeys: [SerializationKeys] {
        [
            .activities,
            .messages,
            .metadata,
            .participants,
            .reactionMetadata,
        ]
    }

    // MARK: - Modify Key

    func modifyKey(_ key: SerializationKeys, withValue value: Any) -> Conversation? {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        switch key {
        case .encodedHash,
             .id:
            return nil

        case .activities:
            guard let value = value as? [Activity] else { return nil }
            return updateIDHash(.init(
                id,
                activities: value,
                messageIDs: messageIDs,
                messages: messages,
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata,
                users: users
            ))

        case .messages:
            guard let value = value as? [Message] else { return nil }
            return updateIDHash(.init(
                id,
                activities: activities,
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
                activities: activities,
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
                activities: activities,
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
                activities: activities,
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

    func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: NetworkServices

        guard updatableKeys.contains(key) else {
            return .failure(.Networking.notUpdatable(
                key: key,
                .init(sender: self)
            ))
        }

        guard var updated = modifyKey(key, withValue: value) else {
            return .failure(.Networking.typeMismatch(
                key: key,
                .init(sender: self)
            ))
        }

        let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(id.key)/"
        let valueKeyPath = conversationKeyPath + key.rawValue

        if key == .messages,
           let messageIDs = (value as? [Message])?.filteringSystemMessages.map(\.id),
           !messageIDs.isEmpty {
            if let exception = await addMessageIDs(messageIDs) {
                return .failure(exception)
            }

            let updateIsTypingResult = await updateIsTyping(updated)
            switch updateIsTypingResult {
            case let .success(conversation): updated = conversation
            case let .failure(exception): return .failure(exception)
            }
        } else if let serializable = value as? any Serializable {
            if let exception = await networking.database.setValue(
                serializable.encoded,
                forKey: valueKeyPath
            ) {
                return .failure(exception)
            }
        } else if let serializable = value as? [any Serializable] {
            // swiftformat:disable all
            let encoded = serializable.map { $0.encoded } // swiftformat:enable all
            if let exception = await networking.database.setValue(
                encoded.isEmpty ? Array.bangQualifiedEmpty : encoded,
                forKey: valueKeyPath
            ) {
                return .failure(exception)
            }
        } else if networking.database.isEncodable(value) {
            if let exception = await networking.database.setValue(
                value,
                forKey: valueKeyPath
            ) {
                return .failure(exception)
            }
        } else {
            return .failure(.Networking.notSerialized(
                data: [key.rawValue: value],
                .init(sender: self)
            ))
        }

        // NIT: Fixes looping updates when updating read receipts, but unsure of efficacy.
        defer { networking.conversationService.archive.addValue(updated) }

        guard updated.id.hash != id.hash else { return .success(updated) }
        let hashPath = conversationKeyPath + SerializationKeys.encodedHash.rawValue
        if let exception = await networking.database.setValue(
            updated.id.hash,
            forKey: hashPath
        ) {
            return .failure(exception)
        }

        if let exception = await propagateUpdatesToUsers(in: updated) {
            return .failure(exception)
        }

        if key == .activities {
            if let exception = await updated.setUsers(forceUpdate: true) {
                return .failure(exception)
            }
        }

        return .success(updated)
    }

    // MARK: - Updates Values

    func updateValues(
        with data: [SerializationKeys: Any]
    ) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        var updated = filteringSystemMessages
        for keyPair in data {
            guard updatableKeys.contains(keyPair.key) else {
                return .failure(.Networking.notUpdatable(
                    key: keyPair.key,
                    .init(sender: self)
                ))
            }

            guard let modified = updated.modifyKey(
                keyPair.key,
                withValue: keyPair.value
            ) else {
                return .failure(.Networking.typeMismatch(
                    key: keyPair.key,
                    .init(sender: self)
                ))
            }

            updated = modified
        }

        // NIT: Can do updateChildValues with encoded filtering all not equal to keys in data.
        let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(updated.id.key)/"
        if let exception = await networking.database.setValue(
            updated.encoded.filter { $0.key != Conversation.SerializationKeys.id.rawValue },
            forKey: conversationKeyPath
        ) {
            return .failure(exception)
        }

        if let exception = await propagateUpdatesToUsers(in: updated) {
            return .failure(exception)
        }

        if data.keys.contains(.activities) {
            if let exception = await updated.setUsers(forceUpdate: true) {
                return .failure(exception)
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

        let messagesKeyPath = [
            NetworkPath.conversations.rawValue,
            id.key,
            Conversation.SerializationKeys.messages.rawValue,
        ].joined(separator: "/")

        let currentMessageIDs: [String]
        var newMessageIDs = messageIDs

        do {
            currentMessageIDs = try await networking.database.getValues(
                at: messagesKeyPath,
                cacheStrategy: .disregardCache
            )
        } catch {
            return error
        }

        newMessageIDs += currentMessageIDs
        if let exception = await networking.database.setValue(
            newMessageIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : newMessageIDs.unique,
            forKey: messagesKeyPath
        ) {
            return exception
        }

        return nil
    }

    private func propagateUpdatesToUsers(
        in conversation: Conversation
    ) async -> Exception? {
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        if let exception = await conversation.setUsers(forceUpdate: true) {
            return exception
        }

        guard var users = conversation.users else {
            return .init(
                "Failed to set users on conversation.",
                metadata: .init(sender: self)
            )
        }

        if let currentUser = userSession.currentUser {
            users.append(currentUser)
        }

        return await withTaskGroup(
            of: Exception?.self,
            returning: [Exception].self
        ) { taskGroup in
            for user in users {
                guard var conversationIDs = user.conversationIDs,
                      let index = conversationIDs.firstIndex(where: {
                          $0.key == conversation.id.key
                      }) else { continue }

                conversationIDs.removeAll(where: { $0.key == conversation.id.key })
                conversationIDs.insert(conversation.id, at: index)

                taskGroup.addTask {
                    let updateValueResult = await user.updateValue(
                        conversationIDs,
                        forKey: .conversationIDs
                    )

                    switch updateValueResult {
                    case let .failure(exception): return exception
                    default: return nil
                    }
                }
            }

            var exceptions = [Exception]()
            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }

            return exceptions
        }.compiledException
    }

    private func updateIDHash(_ conversation: Conversation) -> Conversation {
        .init(
            .init(key: conversation.id.key, hash: conversation.encodedHash),
            activities: conversation.activities,
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
                metadata: .init(sender: self)
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
            activities: conversation.activities,
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
