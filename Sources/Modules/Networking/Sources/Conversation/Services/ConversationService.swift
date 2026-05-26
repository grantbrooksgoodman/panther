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

    // MARK: - Properties

    let archive: ConversationArchiveService

    // MARK: - Init

    init(archive: ConversationArchiveService) {
        self.archive = archive
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

        var mockConversation: Conversation = .init(
            .init(key: id, hash: ""),
            activities: nil,
            messageIDs: [firstMessage.id],
            messages: [firstMessage],
            metadata: .empty(
                userIDs: participants.map(\.userID),
                isPenPalsConversation: isPenPalsConversation
            ),
            participants: participants,
            reactionMetadata: nil,
            users: nil
        )

        let data = mockConversation.encoded.filter {
            $0.key != Conversation.SerializableKey.id.rawValue
        }

        try await networking.database.updateChildValues(
            forKey: "\(path)/\(id)",
            with: data
        )

        let conversationID: ConversationID = .init(
            key: mockConversation.id.key,
            hash: mockConversation.encodedHash
        )

        try await participants.parallelMap {
            try await addConversationToUser(
                userID: $0.userID,
                conversationID: conversationID
            )
        }

        mockConversation = .init(
            conversationID,
            activities: mockConversation.activities,
            messageIDs: mockConversation.messageIDs,
            messages: mockConversation.messages,
            metadata: mockConversation.metadata,
            participants: mockConversation.participants,
            reactionMetadata: nil,
            users: mockConversation.users
        )

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
            return try await idKeys.parallelMap(
                failForEmptyCollection: true
            ) {
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

    private func getConversationIDStrings(
        for userID: String
    ) async throws(Exception) -> [String] {
        try await networking.database.getValues(
            at: [
                NetworkPath.users.rawValue,
                userID,
                User.SerializableKey.conversationIDs.rawValue,
            ].joined(separator: "/")
        )
    }

    // MARK: - Deletion

    func removeConversationFromUsers(
        userIDs: [String],
        conversationIDKey: String,
        failureStrategy: BatchFailureStrategy = .returnOnFailure
    ) async throws(Exception) {
        func removeConversationFromUser(
            userID: String,
            conversationIDKey: String
        ) async throws(Exception) {
            let userInfo = ["UserID": userID, "ConversationIDKey": conversationIDKey]

            guard !userID.isBangQualifiedEmpty,
                  !conversationIDKey.isBangQualifiedEmpty else {
                throw Exception(
                    "Passed arguments fail validation.",
                    metadata: .init(sender: self)
                ).appending(userInfo: userInfo)
            }

            var conversationIDStrings: [String]
            do {
                conversationIDStrings = try await getConversationIDStrings(
                    for: userID
                )
            } catch {
                throw error.appending(userInfo: userInfo)
            }

            conversationIDStrings.removeAll(where: {
                $0.hasPrefix(conversationIDKey)
            })

            conversationIDStrings = conversationIDStrings.isBangQualifiedEmpty ? .bangQualifiedEmpty : conversationIDStrings

            do {
                try await networking.database.setValue(
                    conversationIDStrings,
                    forKey: [
                        NetworkPath.users.rawValue,
                        userID,
                        User.SerializableKey.conversationIDs.rawValue,
                    ].joined(separator: "/")
                )
            } catch {
                throw error.appending(userInfo: userInfo)
            }
        }

        try await userIDs.parallelMap(
            failFast: failureStrategy == .returnOnFailure
        ) {
            try await removeConversationFromUser(
                userID: $0,
                conversationIDKey: conversationIDKey
            )
        }
    }

    // MARK: - Auxiliary

    private func addConversationToUser(
        userID: String,
        conversationID: ConversationID
    ) async throws(Exception) {
        let userInfo = ["UserID": userID, "ConversationID": conversationID.encoded]

        var conversationIDStrings: [String]
        do {
            conversationIDStrings = try await getConversationIDStrings(
                for: userID
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        conversationIDStrings.append(conversationID.encoded)
        conversationIDStrings = conversationIDStrings.filter {
            !$0.isBangQualifiedEmpty
        }.unique

        do {
            try await networking.database.setValue(
                conversationIDStrings,
                forKey: [
                    NetworkPath.users.rawValue,
                    userID,
                    User.SerializableKey.conversationIDs.rawValue,
                ].joined(separator: "/")
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }
}
