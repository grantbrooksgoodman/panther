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

public struct ConversationService {
    // MARK: - Dependencies

    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    public let archive: ConversationArchiveService

    // MARK: - Init

    public init(archive: ConversationArchiveService) {
        self.archive = archive
    }

    // MARK: - Conversation Creation

    public func createConversation(
        firstMessage: Message,
        participants: [Participant]
    ) async -> Callback<Conversation, Exception> {
        guard participants.map(\.isWellFormed).allSatisfy({ $0 == true }) else {
            return .failure(.init(
                "Passed arguments fail validation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let path = NetworkPath.conversations.rawValue
        guard let id = networking.database.generateKey(for: path) else {
            return .failure(.init(
                "Failed to generate key for new conversation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        var mockConversation: Conversation = .init(
            .init(key: id, hash: ""),
            messageIDs: [firstMessage.id],
            messages: [firstMessage],
            metadata: .empty,
            participants: participants,
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
            messageIDs: mockConversation.messageIDs,
            messages: mockConversation.messages,
            metadata: mockConversation.metadata,
            participants: mockConversation.participants,
            users: mockConversation.users
        )

        return .success(mockConversation)
    }

    // MARK: - Retrieval by ID

    public func getConversations(idKeys: [String]) async -> Callback<[Conversation], Exception> {
        let commonParams = ["ConversationIDs": idKeys]

        guard !idKeys.isBangQualifiedEmpty else {
            let exception = Exception("No IDs provided.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        var conversations = [Conversation]()

        for id in idKeys {
            let getConversationResult = await getConversation(idKey: id)

            switch getConversationResult {
            case let .success(conversation):
                conversations.append(conversation)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }
        }

        guard !conversations.isEmpty,
              conversations.count == idKeys.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(conversations)
    }

    private func getConversation(idKey: String) async -> Callback<Conversation, Exception> {
        let commonParams = ["ConversationIDKey": idKey]

        guard !idKey.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let path = NetworkPath.conversations.rawValue
        let getValuesResult = await networking.database.getValues(at: "\(path)/\(idKey)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception: Exception = .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            typealias Keys = Conversation.SerializationKeys
            guard let conversationIDHash = data[Keys.encodedHash.rawValue] as? String else {
                let exception = Exception("Failed to decode conversation ID.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            data[Keys.id.rawValue] = ConversationID(key: idKey, hash: conversationIDHash).encoded
            let decodeResult = await Conversation.decode(from: data)

            switch decodeResult {
            case let .success(conversation):
                return .success(conversation)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    private func getConversationIDStrings(for userID: String) async -> Callback<[String], Exception> {
        let usersPath = NetworkPath.users.rawValue
        let path = "\(usersPath)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.typecastFailed("array", metadata: [self, #file, #function, #line]))
            }

            return .success(array)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Deletion

    public func removeConversationFromUsers(
        userIDs: [String],
        conversationIDKey: String,
        failureStrategy: BatchFailureStrategy = .returnOnFailure
    ) async -> Exception? {
        func removeConversationFromUser(userID: String, conversationIDKey: String) async -> Exception? {
            let commonParams = ["UserID": userID, "ConversationIDKey": conversationIDKey]

            guard !userID.isBangQualifiedEmpty,
                  !conversationIDKey.isBangQualifiedEmpty else {
                let exception = Exception("Passed arguments fail validation.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
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
                    return exception.appending(extraParams: commonParams)
                }

            case let .failure(exception):
                return exception.appending(extraParams: commonParams)
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
        let commonParams = ["UserID": userID, "ConversationID": conversationID.encoded]

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
                return exception.appending(extraParams: commonParams)
            }

        case let .failure(exception):
            return exception.appending(extraParams: commonParams)
        }

        return nil
    }
}
