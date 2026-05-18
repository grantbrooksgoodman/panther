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
    ) async -> Callback<Conversation, Exception> {
        guard participants.map(\.isWellFormed).allSatisfy({ $0 == true }) else {
            return .failure(.init(
                "Passed arguments fail validation.",
                metadata: .init(sender: self)
            ))
        }

        let path = NetworkPath.conversations.rawValue
        guard let id = networking.database.generateKey(for: path) else {
            return .failure(.init(
                "Failed to generate key for new conversation.",
                metadata: .init(sender: self)
            ))
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

        if let exception = await networking.database.updateChildValues(
            forKey: "\(path)/\(id)",
            with: data
        ) {
            return .failure(exception)
        }

        let conversationID: ConversationID = .init(
            key: mockConversation.id.key,
            hash: mockConversation.encodedHash
        )

        if let exception = await participants.parallelMap(perform: {
            await addConversationToUser(
                userID: $0.userID,
                conversationID: conversationID
            )
        }) {
            return .failure(exception)
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

        return .success(mockConversation)
    }

    // MARK: - Retrieval by ID

    func getConversations(idKeys: [String]) async -> Callback<[Conversation], Exception> {
        let userInfo = ["ConversationIDs": idKeys]

        guard !idKeys.isBangQualifiedEmpty else {
            let exception = Exception("No IDs provided.", metadata: .init(sender: self))
            return .failure(exception.appending(userInfo: userInfo))
        }

        let getConversationResults = await idKeys.parallelMap(
            failForEmptyCollection: true
        ) {
            await getConversation(idKey: $0)
        }

        switch getConversationResults {
        case let .success(conversations):
            return .success(conversations)

        case let .failure(exception):
            return .failure(exception.appending(userInfo: userInfo))
        }
    }

    private func getConversation(idKey: String) async -> Callback<Conversation, Exception> {
        let userInfo = ["ConversationIDKey": idKey]

        guard !idKey.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: .init(sender: self))
            return .failure(exception.appending(userInfo: userInfo))
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
            return .failure(error.appending(userInfo: userInfo))
        }

        typealias Keys = Conversation.SerializableKey
        guard let conversationIDHash = data[Keys.encodedHash.rawValue] as? String else {
            let exception = Exception(
                "Failed to decode conversation ID.",
                metadata: .init(sender: self)
            )

            return .failure(exception.appending(userInfo: userInfo))
        }

        data[Keys.id.rawValue] = ConversationID(
            key: idKey,
            hash: conversationIDHash
        ).encoded

        return await .asCallback(
            userInfo: userInfo
        ) { try await Conversation(from: data) }
    }

    private func getConversationIDStrings(for userID: String) async -> Callback<[String], Exception> {
        await .asCallback {
            try await networking.database.getValues(
                at: [
                    NetworkPath.users.rawValue,
                    userID,
                    User.SerializableKey.conversationIDs.rawValue,
                ].joined(separator: "/")
            )
        }
    }

    // MARK: - Deletion

    func removeConversationFromUsers(
        userIDs: [String],
        conversationIDKey: String,
        failureStrategy: BatchFailureStrategy = .returnOnFailure
    ) async -> Exception? {
        func removeConversationFromUser(userID: String, conversationIDKey: String) async -> Exception? {
            let userInfo = ["UserID": userID, "ConversationIDKey": conversationIDKey]

            guard !userID.isBangQualifiedEmpty,
                  !conversationIDKey.isBangQualifiedEmpty else {
                let exception = Exception("Passed arguments fail validation.", metadata: .init(sender: self))
                return exception.appending(userInfo: userInfo)
            }

            let getConversationIDStringsResult = await getConversationIDStrings(for: userID)

            switch getConversationIDStringsResult {
            case var .success(conversationIDStrings):
                conversationIDStrings.removeAll(where: { $0.hasPrefix(conversationIDKey) })
                conversationIDStrings = conversationIDStrings.isBangQualifiedEmpty ? .bangQualifiedEmpty : conversationIDStrings

                let path = NetworkPath.users.rawValue
                if let exception = await networking.database.setValue(
                    conversationIDStrings,
                    forKey: "\(path)/\(userID)/\(User.SerializableKey.conversationIDs.rawValue)"
                ) {
                    return exception.appending(userInfo: userInfo)
                }

            case let .failure(exception):
                return exception.appending(userInfo: userInfo)
            }

            return nil
        }

        return await userIDs.parallelMap(
            failFast: failureStrategy == .returnOnFailure
        ) {
            await removeConversationFromUser(
                userID: $0,
                conversationIDKey: conversationIDKey
            )
        }
    }

    // MARK: - Auxiliary

    private func addConversationToUser(userID: String, conversationID: ConversationID) async -> Exception? {
        let userInfo = ["UserID": userID, "ConversationID": conversationID.encoded]

        let getConversationIDStringsResult = await getConversationIDStrings(for: userID)

        switch getConversationIDStringsResult {
        case var .success(conversationIDStrings):
            conversationIDStrings.append(conversationID.encoded)
            conversationIDStrings = conversationIDStrings.filter { !$0.isBangQualifiedEmpty }.unique

            let path = NetworkPath.users.rawValue
            if let exception = await networking.database.setValue(
                conversationIDStrings,
                forKey: "\(path)/\(userID)/\(User.SerializableKey.conversationIDs.rawValue)"
            ) {
                return exception.appending(userInfo: userInfo)
            }

        case let .failure(exception):
            return exception.appending(userInfo: userInfo)
        }

        return nil
    }
}
