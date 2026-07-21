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

struct ConversationService {
    // MARK: - Dependencies

    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) var sessionStore: SessionStore

    // MARK: - Properties

    let staging: ConversationStagingService

    // MARK: - Init

    init(staging: ConversationStagingService) {
        self.staging = staging
    }

    // MARK: - Conversation Creation

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

        try await networking.database.commit(updates)
        mockConversation = mockConversation.copying(id: conversationID)
        return mockConversation
    }

    // MARK: - Retrieval by ID

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
                ].joined(separator: "/")
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
