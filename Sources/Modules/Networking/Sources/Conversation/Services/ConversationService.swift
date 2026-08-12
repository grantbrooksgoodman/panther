//
//  ConversationService.swift
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

/// The service that creates, retrieves, and removes conversations.
///
/// ``ConversationService`` creates conversations, fetches them by identifier, and removes them
/// from users. It delegates conversation staging to its ``staging`` sub-service.
struct ConversationService {
    // MARK: - Dependencies

    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) var sessionStore: SessionStore

    // MARK: - Properties

    /// The service that stages sample conversations during development.
    let staging: ConversationStagingService

    // MARK: - Init

    /// Creates a conversation service with the given staging service.
    ///
    /// - Parameter staging: The service that stages sample conversations during development.
    init(staging: ConversationStagingService) {
        self.staging = staging
    }

    // MARK: - Conversation Creation

    /// Creates a conversation with the given first message and participants, and writes it to the
    /// database.
    ///
    /// The conversation node, the participants' conversation tokens, the first message node, and
    /// any pending hosted translation archive entries are written in a single atomic fan-out.
    ///
    /// - Parameters:
    ///   - firstMessage: The conversation's first message.
    ///   - isPenPalsConversation: A Boolean value that indicates whether the conversation is a
    ///     PenPals conversation.
    ///   - participants: The conversation's participants.
    ///
    /// - Returns: The created conversation.
    ///
    /// - Throws: An `Exception` if the participants fail validation, a key cannot be generated, or
    ///   the write fails.
    func createConversation(
        firstMessage: Message,
        isPenPalsConversation: Bool,
        participants: [Participant]
    ) async throws(Exception) -> Conversation {
        guard participants.map(\.isWellFormed).allSatisfy({ $0 == true }) else {
            throw Exception(
                "Passed arguments fail validation.",
                metadata: .init(sender: self)
            )
        }

        let path = NetworkPath.conversations.rawValue
        guard let id = networking.database.generateKey(for: path) else {
            throw Exception(
                "Failed to generate key for new conversation.",
                metadata: .init(sender: self)
            )
        }

        // Optimistic insert before remote write; didWrite does not apply.
        sessionStore.upsertMessages([firstMessage])
        var mockConversation: Conversation = .init(
            .init(key: id, hash: ""),
            activities: nil,
            messageIDs: [firstMessage.id],
            metadata: .empty(
                userIDs: participants.map(\.userID),
                isPenPalsConversation: isPenPalsConversation
            ),
            participants: participants,
            reactionMetadata: nil
        )

        let data = mockConversation.encoded.filter {
            $0.key != Conversation.SerializableKey.id.rawValue
        }

        let conversationID: ConversationID = .init(
            key: mockConversation.id.key,
            hash: mockConversation.encodedHash
        )

        var updates: [String: Any] = [:]
        for (key, value) in data {
            updates[
                [
                    path,
                    id,
                    key,
                ].joined(separator: "/")
            ] = value
        }

        for participant in participants {
            updates[
                [
                    NetworkPath.users.rawValue,
                    participant.userID,
                    User.SerializableKey.conversationIDs.rawValue,
                    conversationID.key,
                ].joined(separator: "/")
            ] = conversationID.hash
        }

        // The message node joins the same atomic fan-out;
        // buildMessage leaves it unwritten on the send path.
        updates[
            [
                NetworkPath.messages.rawValue,
                firstMessage.id,
            ].joined(separator: "/")
        ] = firstMessage.encoded.filter {
            $0.key != Message.SerializableKey.id.rawValue
        }

        // Merge pending hosted-archive entries into the same payload;
        // a message node must never commit without its translations
        // being resolvable from the hosted archive.
        for reference in firstMessage.translationReferences ?? [] {
            guard let entry = PendingTranslationArchive.drain(
                for: reference.hostingKey
            ) else { continue }
            updates[entry.key] = entry.value
        }

        try await networking.database.commit(updates)
        mockConversation = mockConversation.copying(id: conversationID)
        return mockConversation
    }

    // MARK: - Retrieval by ID

    /// Returns the conversations with the given identifier keys, fetched concurrently.
    ///
    /// - Parameter idKeys: The identifier keys of the conversations to fetch.
    ///
    /// - Returns: The conversations.
    ///
    /// - Throws: An `Exception` if no identifier keys are provided or any conversation cannot be
    ///   fetched.
    func getConversations(
        idKeys: [String]
    ) async throws(Exception) -> [Conversation] {
        let userInfo = ["ConversationIDs": idKeys]

        guard !idKeys.isBangQualifiedEmpty else {
            throw Exception(
                "No IDs provided.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        do {
            return try await idKeys.parallelMap {
                try await getConversation(idKey: $0)
            }
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

    private func getConversation(
        idKey: String
    ) async throws(Exception) -> Conversation {
        let userInfo = ["ConversationIDKey": idKey]

        guard !idKey.isBangQualifiedEmpty else {
            throw Exception(
                "No ID provided.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        var data: [String: Any]
        do {
            data = try await networking.database.getValues(
                at: [
                    NetworkPath.conversations.rawValue,
                    idKey,
                ].joined(separator: "/"), // TODO: Audit the cache strategy here.
                cacheStrategy: .disregardCache
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        typealias Keys = Conversation.SerializableKey
        guard let conversationIDHash = data[Keys.encodedHash.rawValue] as? String else {
            throw Exception(
                "Failed to decode conversation ID.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        data[Keys.id.rawValue] = ConversationID(
            key: idKey,
            hash: conversationIDHash
        ).encoded

        do {
            return try await Conversation(from: data)
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

    // MARK: - Deletion

    /// Removes the conversation with the given identifier key from the given users.
    ///
    /// This method deletes each user's token for the conversation in a single atomic fan-out.
    ///
    /// - Parameters:
    ///   - userIDs: The identifiers of the users to remove the conversation from.
    ///   - conversationIDKey: The identifier key of the conversation to remove.
    ///   - failureStrategy: The strategy that determines how a failure is handled.
    ///
    /// - Throws: An `Exception` if the conversation identifier key is empty or the write fails.
    func removeConversationFromUsers(
        userIDs: [String],
        conversationIDKey: String,
        failureStrategy: BatchFailureStrategy = .returnOnFailure
    ) async throws(Exception) {
        guard !conversationIDKey.isBangQualifiedEmpty else {
            throw Exception(
                "Passed arguments fail validation.",
                metadata: .init(sender: self)
            )
        }

        var updates = [String: Any]()
        for userID in userIDs where !userID.isBangQualifiedEmpty {
            let path = [
                NetworkPath.users.rawValue,
                userID,
                User.SerializableKey.conversationIDs.rawValue,
                conversationIDKey,
            ].joined(separator: "/")

            updates[path] = NSNull()
        }

        try await networking.database.commit(updates)
    }
}
