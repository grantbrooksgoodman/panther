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

        let data = mockConversation.encoded.filter { $0.key != Conversation.SerializationKeys.id.rawValue }

        if let exception = await networking.database.updateChildValues(forKey: "\(path)/\(id)", with: data) {
            return .failure(exception)
        }

        let conversationID: ConversationID = .init(key: mockConversation.id.key, hash: mockConversation.encodedHash)

        for participant in participants {
            if let exception = await addConversationToUser(
                userID: participant.userID,
                conversationID: conversationID
            ) {
                return .failure(exception)
            }
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

        var conversations = [Conversation]()

        for id in idKeys {
            let getConversationResult = await getConversation(idKey: id)

            switch getConversationResult {
            case let .success(conversation):
                conversations.append(conversation)

            case let .failure(exception):
                return .failure(exception.appending(userInfo: userInfo))
            }
        }

        guard !conversations.isEmpty,
              conversations.count == idKeys.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo))
        }

        return .success(conversations)
    }

    private func getConversation(idKey: String) async -> Callback<Conversation, Exception> {
        let userInfo = ["ConversationIDKey": idKey]

        guard !idKey.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: .init(sender: self))
            return .failure(exception.appending(userInfo: userInfo))
        }

        let path = NetworkPath.conversations.rawValue
        let getValuesResult = await networking.database.getValues(at: "\(path)/\(idKey)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception: Exception = .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
                return .failure(exception.appending(userInfo: userInfo))
            }

            typealias Keys = Conversation.SerializationKeys
            guard let conversationIDHash = data[Keys.encodedHash.rawValue] as? String else {
                let exception = Exception("Failed to decode conversation ID.", metadata: .init(sender: self))
                return .failure(exception.appending(userInfo: userInfo))
            }

            data[Keys.id.rawValue] = ConversationID(key: idKey, hash: conversationIDHash).encoded
            let decodeResult = await Conversation.decode(from: data)

            switch decodeResult {
            case let .success(conversation):
                return .success(conversation)

            case let .failure(exception):
                return .failure(exception.appending(userInfo: userInfo))
            }

        case let .failure(exception):
            return .failure(exception.appending(userInfo: userInfo))
        }
    }

    private func getConversationIDStrings(for userID: String) async -> Callback<[String], Exception> {
        let usersPath = NetworkPath.users.rawValue
        let path = "\(usersPath)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.Networking.typecastFailed("array", metadata: .init(sender: self)))
            }

            return .success(array)

        case let .failure(exception):
            return .failure(exception)
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
                    forKey: "\(path)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                ) {
                    return exception.appending(userInfo: userInfo)
                }

            case let .failure(exception):
                return exception.appending(userInfo: userInfo)
            }

            return nil
        }

        var exceptions = [Exception]()

        for userID in userIDs {
            if let exception = await removeConversationFromUser(
                userID: userID,
                conversationIDKey: conversationIDKey
            ) {
                guard failureStrategy == .returnOnFailure else {
                    exceptions.append(exception)
                    continue
                }

                return exception
            }
        }

        return exceptions.compiledException
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
                forKey: "\(path)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
            ) {
                return exception.appending(userInfo: userInfo)
            }

        case let .failure(exception):
            return exception.appending(userInfo: userInfo)
        }

        return nil
    }
}
