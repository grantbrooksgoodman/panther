//
//  Conversation+RemotelyUpdatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension Conversation: RemotelyUpdatable {
    // MARK: - Properties

    /// The conversation's identifier.
    var identifier: String {
        id.key
    }

    // MARK: - Serializable Key

    /// Returns the serializable key for the given key path, or `nil` if the key path is not
    /// remotely updatable.
    ///
    /// - Parameter keyPath: The key path to map to a serializable key.
    ///
    /// - Returns: The serializable key for the key path, or `nil` if the key path is not remotely
    ///   updatable.
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

    /// Returns a copy of the conversation with the given key set to the given value.
    ///
    /// Returns `nil` if the value's type does not match the key, or if the key is not modifiable.
    ///
    /// - Parameters:
    ///   - key: The serializable key of the field to modify.
    ///   - value: The new value for the field.
    ///
    /// - Returns: The modified conversation, or `nil` if the modification cannot be applied.
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

            // The session store never stores system messages; filter
            // them here too so hydrated display arrays can't leak
            // their IDs into the conversation's message IDs.
            let messages = value.uniquedByID.filteringSystemMessages

            // Messages set via updateValues bypass Message.didWrite.
            sessionStore.upsertMessages(Set(messages))
            return updateIDHash(
                copying(messageIDs: messages.map(\.id).unique)
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

    /// Applies the given key-path updates to the conversation and writes the changed fields to the
    /// database.
    ///
    /// Only the touched fields, the conversation's hash token, and the participants' hash tokens
    /// are written, in a single atomic fan-out. On success, the updated conversation is upserted
    /// into the session store.
    ///
    /// - Parameter data: The updates to apply, keyed by key path.
    ///
    /// - Returns: The updated conversation.
    ///
    /// - Throws: An `Exception` if a key path is not remotely updatable, a value's type does not
    ///   match its key, or the write fails.
    func updateValues(
        with data: [PartialKeyPath<Conversation>: Any]
    ) async throws(Exception) -> Conversation {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        var changedKeys = Set<String>()
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
            changedKeys.insert(key.rawValue)
        }

        let conversationPath = [
            NetworkPath.conversations.rawValue,
            updated.id.key,
        ].joined(separator: "/")

        // Fan-out only the touched keys + hash + user tokens.
        var updates = [String: Any]()

        for (key, value) in updated.encoded where changedKeys.contains(key) {
            updates[
                "\(conversationPath)/\(key)"
            ] = value
        }

        updates[
            "\(conversationPath)/\(SerializableKey.encodedHash.rawValue)"
        ] = updated.id.hash

        updates.merge(
            buildParticipantUpdates(for: updated),
            uniquingKeysWith: { _, new in new }
        )

        SelfWriteRegistry.record(updated.id)
        try await database.commit(updates)

        // updateValues bypasses didWrite; this is its only upsert.
        sessionStore.upsertConversation(updated)
        return updated
    }

    // MARK: - Will Write

    /// Prepares a single-field remote update before it is written.
    ///
    /// When new messages are written, this method commits the message nodes, their conversation
    /// index entries, an un-delete of every participant, a reset of the current user's typing
    /// status, the conversation's hash token and last-modified date, the participants' hash
    /// tokens, and any pending hosted translation archive entries, all in a single atomic fan-out.
    /// Other fields proceed with the default write.
    ///
    /// - Parameters:
    ///   - value: The new value being written.
    ///   - key: The serializable key of the field being updated.
    ///   - updated: The conversation as it will be after the update.
    ///
    /// - Returns: The action the update system should take.
    ///
    /// - Throws: An `Exception` if the current user participant cannot be resolved or committing
    ///   the fan-out fails.
    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: Conversation
    ) async throws(Exception) -> WriteAction<Conversation> {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter

        guard key == .messages,
              let messages = value as? [Message],
              !messages.filteringSystemMessages.isEmpty else { return .proceed }

        let newMessages = messages
            .filteringSystemMessages
            .filter { !Set(messageIDs).contains($0.id) }

        let conversationPath = [
            NetworkPath.conversations.rawValue,
            updated.id.key,
        ].joined(separator: "/")

        guard let currentUserParticipant = updated.currentUserParticipant else {
            throw Exception(
                "Failed to resolve current user participant.",
                metadata: .init(sender: self)
            )
        }

        // Reset typing for current user + un-delete all
        // participants (sending revives the conversation).
        let conversation = updateIDHash(
            updated.copying(
                participants: participants.map {
                    .init(
                        userID: $0.userID,
                        hasDeletedConversation: false,
                        isTyping: $0.userID == currentUserParticipant.userID ? false : $0.isTyping
                    )
                }
            )
        )

        // Single atomic fan-out: message node data +
        // conversation index entries + participant
        // un-delete + typing reset + hash +
        // lastModifiedDate + user tokens.
        var updates = [String: Any]()

        // Update message data.
        for message in newMessages {
            updates[
                "\(NetworkPath.messages.rawValue)/\(message.id)"
            ] = message.encoded.filter {
                $0.key != Message.SerializableKey.id.rawValue
            }
        }

        // Update message index entries in conversation.
        for newMessage in newMessages {
            updates[
                [
                    conversationPath,
                    SerializableKey.messages.rawValue,
                    newMessage.id,
                ].joined(separator: "/")
            ] = true
        }

        // Un-delete participants who have deleted the conversation.
        for participant in updated.participants where participant.hasDeletedConversation {
            updates[
                [
                    conversationPath,
                    SerializableKey.participants.rawValue,
                    participant.userID,
                    Participant.SerializableKey.hasDeletedConversation.rawValue,
                ].joined(separator: "/")
            ] = false
        }

        // Reset typing status for current user.
        updates[
            [
                conversationPath,
                SerializableKey.participants.rawValue,
                currentUserParticipant.userID,
                Participant.SerializableKey.isTyping.rawValue,
            ].joined(separator: "/")
        ] = false

        // Update conversation hash.
        updates[
            "\(conversationPath)/\(SerializableKey.encodedHash.rawValue)"
        ] = conversation.id.hash

        // Update last modified date.
        updates[
            [
                conversationPath,
                SerializableKey.metadata.rawValue,
                ConversationMetadata.SerializableKey.lastModifiedDate.rawValue,
            ].joined(separator: "/")
        ] = timestampDateFormatter.string(from: .now)

        // Update participant data for conversation change.
        updates.merge(
            buildParticipantUpdates(for: conversation),
            uniquingKeysWith: { _, new in new }
        )

        // Merge pending hosted-archive entries into the same payload;
        // a message node must never commit without its translations
        // being resolvable from the hosted archive.
        for newMessage in newMessages {
            for reference in newMessage.translationReferences ?? [] {
                guard let entry = PendingTranslationArchive.drain(
                    for: reference.hostingKey
                ) else { continue }
                updates[entry.key] = entry.value
            }
        }

        SelfWriteRegistry.record(conversation.id)
        try await database.commit(updates)
        return .handled(conversation)
    }

    // MARK: - Did Update

    /// Applies a completed single-field remote update, upserting the updated conversation into the
    /// session store.
    ///
    /// Unless the field written was ``SerializableKey/messages``, this method also writes the
    /// conversation's new hash token and the participants' hash tokens in a single atomic fan-out.
    /// Updates to the messages field write these entries as part of their own fan-out in
    /// ``willWrite(_:forKey:updating:)``.
    ///
    /// - Parameters:
    ///   - updated: The updated conversation.
    ///   - key: The serializable key of the field that was updated.
    ///
    /// - Returns: The updated conversation.
    ///
    /// - Throws: An `Exception` if applying the update fails.
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

        updates[
            [
                networkPath.rawValue,
                identifier,
                SerializableKey.encodedHash.rawValue,
            ].joined(separator: "/")
        ] = updated.id.hash

        updates.merge(
            buildParticipantUpdates(for: updated),
            uniquingKeysWith: { _, new in new }
        )

        SelfWriteRegistry.record(updated.id)
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
    ///
    /// Callers merge these into their own atomic
    /// ``DatabaseDelegate/commit(_:)`` call.
    private func buildParticipantUpdates(
        for conversation: Conversation
    ) -> [String: Any] {
        var updates = [String: Any]()
        for participant in conversation.participants {
            updates[
                [
                    NetworkPath.users.rawValue,
                    participant.userID,
                    User.SerializableKey.conversationIDs.rawValue,
                    conversation.id.key,
                ].joined(separator: "/")
            ] = conversation.id.hash
        }

        return updates
    }

    private func updateIDHash(
        _ conversation: Conversation
    ) -> Conversation {
        conversation.copying(
            id: .init(
                key: conversation.id.key,
                hash: conversation.encodedHash
            )
        )
    }
}

// swiftlint:enable file_length
