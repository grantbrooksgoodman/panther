//
//  Conversation+RemotelyUpdatable.swift
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

extension Conversation: RemotelyUpdatable {
    // MARK: - Properties

    var identifier: String {
        id.key
    }

    // MARK: - Serializable Key

    static func serializableKey(
        for keyPath: PartialKeyPath<Conversation>
    ) -> SerializableKey? {
        switch keyPath {
        case \.activities: .activities
        case \.messages: .messages
        case \.metadata: .metadata
        case \.participants: .participants
        case \.reactionMetadata: .reactionMetadata
        default: nil
        }
    }

    // MARK: - Modify Key

    func modifyKey(
        _ key: SerializableKey,
        withValue value: Any
    ) -> Conversation? {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        switch key {
        case .encodedHash,
             .id:
            return nil

        case .activities:
            return (value as? [Activity]).map {
                updateIDHash(copying(activities: $0))
            }

        case .messages:
            guard let value = value as? [Message] else { return nil }
            // Messages set via updateValues bypass Message.didWrite.
            sessionStore.upsertMessages(Set(value.uniquedByID))
            return updateIDHash(
                copying(messageIDs: value.map(\.id).unique)
            )

        case .metadata:
            return (value as? ConversationMetadata).map {
                updateIDHash(copying(metadata: $0))
            }

        case .participants:
            return (value as? [Participant]).map {
                updateIDHash(copying(participants: $0))
            }

        case .reactionMetadata:
            guard let value = value as? [ReactionMetadata] else { return nil }
            return updateIDHash(copying(
                reactionMetadata: value.allSatisfy { $0 == .empty } ||
                    value.isEmpty ? nil : value
            ))
        }
    }

    // MARK: - Updates Values

    func updateValues(
        with data: [PartialKeyPath<Conversation>: Any]
    ) async throws(Exception) -> Conversation {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        var updated = filteringSystemMessages
        for keyPair in data {
            guard let key = Self.serializableKey(for: keyPair.key) else {
                throw .Networking.notRemotelyUpdatable(
                    key: keyPair.key,
                    .init(sender: self)
                )
            }

            guard let modified = updated.modifyKey(
                key,
                withValue: keyPair.value
            ) else {
                throw .Networking.typeMismatch(
                    key: key,
                    type: type(of: keyPair.value),
                    .init(sender: self)
                )
            }

            updated = modified
        }

        // NIT: Can do updateChildValues with encoded filtering all not equal to keys in data.
        try await networking.database.setValue(
            updated.encoded.filter { $0.key != Conversation.SerializableKey.id.rawValue },
            forKey: [
                NetworkPath.conversations.rawValue,
                updated.id.key,
            ].joined(separator: "/")
        )

        try await propagateUpdatesToUsers(in: updated)
        if data.keys.contains(\.activities) {
            try await updated.resolveUsers(forceUpdate: true)
        }

        // updateValues bypasses didWrite; this is its only upsert.
        sessionStore.upsertConversation(updated)
        return updated
    }

    // MARK: - Will Write

    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: Conversation
    ) async throws(Exception) -> WriteAction<Conversation> {
        guard key == .messages,
              let messageIDs = (value as? [Message])?.filteringSystemMessages.map(\.id),
              !messageIDs.isEmpty else { return .proceed }

        try await addMessageIDs(messageIDs)
        return try await .handled(updateIsTyping(updated))
    }

    // MARK: - Did Update

    func didWrite(
        _ updated: Conversation,
        forKey key: SerializableKey
    ) async throws(Exception) -> Conversation {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        // Single source of upsert for single-field update calls.
        defer { sessionStore.upsertConversation(updated) }
        guard updated.id.hash != id.hash else { return updated }

        try await networking.database.setValue(
            updated.id.hash,
            forKey: [
                networkPath.rawValue,
                identifier,
                SerializableKey.encodedHash.rawValue,
            ].joined(separator: "/")
        )

        try await propagateUpdatesToUsers(in: updated)
        guard key == .activities else { return updated }
        try await updated.resolveUsers(forceUpdate: true)
        return updated
    }

    // MARK: - Auxiliary

    /// Ensures updates take into account any messages sent during execution of `update` logic.
    /// We disregard modification of the local value, since the store upsert propagates the change via `sessionStoreDidChange`.
    private func addMessageIDs(
        _ messageIDs: [String]
    ) async throws(Exception) {
        @Dependency(\.networking) var networking: NetworkServices

        let messagesKeyPath = [
            NetworkPath.conversations.rawValue,
            id.key,
            Conversation.SerializableKey.messages.rawValue,
        ].joined(separator: "/")

        var newMessageIDs = messageIDs
        let currentMessageIDs: [String] = try await networking.database.getValues(
            at: messagesKeyPath,
            cacheStrategy: .disregardCache
        )

        newMessageIDs += currentMessageIDs
        try await networking.database.setValue(
            newMessageIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : newMessageIDs.unique,
            forKey: messagesKeyPath
        )
    }

    private func propagateUpdatesToUsers(
        in conversation: Conversation
    ) async throws(Exception) {
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        try await conversation.resolveUsers(forceUpdate: true)
        guard var users = conversation.users else {
            throw Exception(
                "Failed to set users on conversation.",
                metadata: .init(sender: self)
            )
        }

        if let currentUser = userSession.currentUser {
            users.append(currentUser)
        }

        let eligibleUsers: [(
            user: User,
            conversationIDs: [ConversationID]
        )] = users
            .compactMap { user in
                guard var conversationIDs = user.conversationIDs,
                      let index = conversationIDs.firstIndex(where: {
                          $0.key == conversation.id.key
                      }) else { return nil }

                conversationIDs.removeAll(where: { $0.key == conversation.id.key })
                conversationIDs.insert(conversation.id, at: index)
                return (user, conversationIDs)
            }

        try await eligibleUsers.map(
            failFast: false
        ) {
            _ = try await $0.user.update(
                \.conversationIDs,
                to: $0.conversationIDs
            )
        }
    }

    private func updateIDHash(_ conversation: Conversation) -> Conversation {
        conversation.copying(
            id: .init(
                key: conversation.id.key,
                hash: conversation.encodedHash
            )
        )
    }

    /// It's optimal to set `isTyping` to `false` in the same call as appending messages during a send operation so the conversation hash doesn't need to be recomputed twice.
    private func updateIsTyping(
        _ conversation: Conversation
    ) async throws(Exception) -> Conversation {
        @Dependency(\.networking) var networking: NetworkServices

        guard let currentUserParticipant = conversation.currentUserParticipant else {
            throw Exception(
                "Failed to resolve current user participant.",
                metadata: .init(sender: self)
            )
        }

        var newParticipants = [Participant]()
        newParticipants = participants.filter { $0 != currentUserParticipant }
        newParticipants.append(.init(
            userID: currentUserParticipant.userID,
            hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
            isTyping: false
        ))

        // TODO: Audit whether or not it is necessary to update the ID hash here.
        let updatedConversation = updateIDHash(
            conversation.copying(participants: newParticipants)
        )

        try await networking.database.setValue(
            updatedConversation.participants.map(\.encoded),
            forKey: [
                NetworkPath.conversations.rawValue,
                updatedConversation.id.key,
                SerializableKey.participants.rawValue,
            ].joined(separator: "/")
        )

        return updatedConversation
    }
}
