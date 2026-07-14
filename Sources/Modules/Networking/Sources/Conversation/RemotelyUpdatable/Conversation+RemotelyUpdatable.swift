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
        @Dependency(\.networking.database) var database: DatabaseDelegate
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        var updated = filteringSystemMessages
        var changedKeys = Set<String>()

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
            changedKeys.insert(key.rawValue)
        }

        let conversationPath = [
            NetworkPath.conversations.rawValue,
            updated.id.key,
        ].joined(separator: "/")

        // Fan-out only the touched keys + hash + user tokens.
        var updates = [String: Any]()

        for (key, value) in updated.encoded where changedKeys.contains(key) {
            updates["\(conversationPath)/\(key)"] = value
        }

        updates["\(conversationPath)/\(SerializableKey.encodedHash.rawValue)"] = updated.id.hash
        updates.merge(
            openConversationsFanOutEntries(for: updated),
            uniquingKeysWith: { _, new in new }
        )

        try await database.commit(updates)

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
              let allMessages = value as? [Message],
              !allMessages.filteringSystemMessages.isEmpty else { return .proceed }

        let existingMessageIDs = Set(messageIDs)
        let trulyNewMessages = allMessages
            .filteringSystemMessages
            .filter { !existingMessageIDs.contains($0.id) }

        let conversationPath = [
            NetworkPath.conversations.rawValue,
            updated.id.key,
        ].joined(separator: "/")

        // Reset typing indicator for current user.
        guard let currentUserParticipant = updated.currentUserParticipant else {
            throw Exception(
                "Failed to resolve current user participant.",
                metadata: .init(sender: self)
            )
        }

        // Reset typing for current user + un-delete all
        // participants (sending revives the conversation).
        var sendPathConversation = updated.copying(
            participants: participants.map { participant in
                let isCurrentUser = participant.userID == currentUserParticipant.userID
                return Participant(
                    userID: participant.userID,
                    hasDeletedConversation: false,
                    isTyping: isCurrentUser ? false : participant.isTyping
                )
            }
        )

        sendPathConversation = updateIDHash(sendPathConversation)

        // Single atomic fan-out: message node data +
        // conversation index entries + participant
        // un-delete + typing reset + hash +
        // lastModifiedDate + user tokens.
        var updates = [String: Any]()

        // Message RTDB nodes for truly-new messages.
        for message in trulyNewMessages {
            let payload = message.encoded.filter {
                $0.key != Message.SerializableKey.id.rawValue
            }

            updates["\(NetworkPath.messages.rawValue)/\(message.id)"] = payload
        }

        // Conversation message index entries.
        for message in trulyNewMessages {
            updates["\(conversationPath)/\(SerializableKey.messages.rawValue)/\(message.id)"] = true
        }

        // Un-delete participants who have deleted the conversation.
        for participant in updated.participants where participant.hasDeletedConversation {
            updates["\(conversationPath)/\(SerializableKey.participants.rawValue)/\(participant.userID)/hasDeletedConversation"] = false
        }

        @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter

        updates["\(conversationPath)/\(SerializableKey.participants.rawValue)/\(currentUserParticipant.userID)/isTyping"] = false
        updates["\(conversationPath)/\(SerializableKey.encodedHash.rawValue)"] = sendPathConversation.id.hash
        updates["\(conversationPath)/\(SerializableKey.metadata.rawValue)/lastModifiedDate"] = timestampDateFormatter.string(from: .now)
        updates.merge(
            openConversationsFanOutEntries(for: sendPathConversation),
            uniquingKeysWith: { _, new in new }
        )

        @Dependency(\.networking.database) var database: DatabaseDelegate
        try await database.commit(updates)
        return .handled(sendPathConversation)
    }

    // MARK: - Did Update

    func didWrite(
        _ updated: Conversation,
        forKey key: SerializableKey
    ) async throws(Exception) -> Conversation {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        // Single source of upsert for single-field update calls.
        defer { sessionStore.upsertConversation(updated) }

        // willWrite(.messages) already commits hash and
        // user tokens as part of its atomic fan-out.
        guard key != .messages,
              updated.id.hash != id.hash else { return updated }

        var updates = [String: Any]()

        let hashPath = [
            networkPath.rawValue,
            identifier,
            SerializableKey.encodedHash.rawValue,
        ].joined(separator: "/")

        updates[hashPath] = updated.id.hash
        updates.merge(
            openConversationsFanOutEntries(for: updated),
            uniquingKeysWith: { _, new in new }
        )

        try await database.commit(updates)
        return updated
    }

    // MARK: - Auxiliary

    /// Builds fan-out entries that update each
    /// participant's `openConversations/<key>` to the
    /// conversation's current hash token.
    ///
    /// Returns entries keyed by environment-relative paths
    /// (for example,
    /// `"users/<uid>/openConversations/<key>": "<hash>"`).
    /// Callers merge these into their own atomic
    /// ``DatabaseDelegate/commit(_:)`` call.
    func openConversationsFanOutEntries(
        for conversation: Conversation
    ) -> [String: Any] {
        var entries = [String: Any]()
        for participant in conversation.participants {
            let path = [
                NetworkPath.users.rawValue,
                participant.userID,
                User.SerializableKey.conversationIDs.rawValue,
                conversation.id.key,
            ].joined(separator: "/")

            entries[path] = conversation.id.hash
        }

        return entries
    }

    private func updateIDHash(_ conversation: Conversation) -> Conversation {
        conversation.copying(
            id: .init(
                key: conversation.id.key,
                hash: conversation.encodedHash
            )
        )
    }
}
