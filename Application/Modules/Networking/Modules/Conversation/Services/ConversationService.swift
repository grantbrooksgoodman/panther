//
//  ConversationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct ConversationService {
    // MARK: - Dependencies

    @Dependency(\.standardDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: Networking

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

        let path = networking.config.paths.conversations
        guard let id = networking.database.generateKey(for: path) else {
            return .failure(.init(
                "Failed to generate key for new conversation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let mockConversation: Conversation = .init(
            .init(key: id, hash: ""),
            messages: [firstMessage],
            lastModifiedDate: Date(),
            participants: participants,
            users: nil
        )

        typealias Keys = Conversation.SerializationKeys
        let data: [String: Any] = [
            Keys.compressedHash.rawValue: mockConversation.compressedHash,
            Keys.messages.rawValue: mockConversation.messages.map(\.id),
            Keys.lastModifiedDate.rawValue: dateFormatter.string(from: mockConversation.lastModifiedDate),
            Keys.participants.rawValue: mockConversation.participants.map(\.encoded),
        ]

        if let exception = await networking.database.updateChildValues(forKey: "\(path)/\(id)", with: data) {
            return .failure(exception)
        }

        let conversationID: ConversationID = .init(key: mockConversation.id.key, hash: mockConversation.compressedHash)

        for participant in participants {
            if let exception = await addConversationToUser(
                userID: participant.userID,
                conversationID: conversationID
            ) {
                return .failure(exception)
            }
        }

        let modifiedMockConversation: Conversation = .init(
            conversationID,
            messages: mockConversation.messages,
            lastModifiedDate: mockConversation.lastModifiedDate,
            participants: mockConversation.participants,
            users: mockConversation.users
        )

        return .success(modifiedMockConversation)
    }

    // MARK: - Retrieval by ID

    public func getConversation(id: String) async -> Callback<Conversation, Exception> {
        let commonParams = ["ConversationIDKey": id]

        guard !id.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let path = networking.config.paths.conversations
        let getValuesResult = await networking.database.getValues(at: "\(path)/\(id)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception = Exception("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            typealias Keys = Conversation.SerializationKeys
            guard let conversationIDHash = data[Keys.compressedHash.rawValue] as? String else {
                let exception = Exception("Failed to decode conversation ID.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            data[Keys.id.rawValue] = ConversationID(key: id, hash: conversationIDHash).encoded
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

    public func getConversationIDStrings(for userID: String) async -> Callback<[String], Exception> {
        let usersPath = networking.config.paths.users
        let path = "\(usersPath)/\(userID)/\(User.SerializationKeys.conversations.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.init("Failed to typecast values to array.", metadata: [self, #file, #function, #line]))
            }

            return .success(array)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    public func getConversations(ids: [String]) async -> Callback<[Conversation], Exception> {
        let commonParams = ["ConversationIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            let exception = Exception("No IDs provided.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        var conversations = [Conversation]()

        for id in ids {
            let getConversationResult = await getConversation(id: id)

            switch getConversationResult {
            case let .success(conversation):
                conversations.append(conversation)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }
        }

        guard !conversations.isEmpty,
              conversations.count == ids.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(conversations)
    }

    // MARK: - Auxiliary

    private func addConversationToUser(userID: String, conversationID: ConversationID) async -> Exception? {
        let commonParams = ["UserID": userID, "ConversationID": conversationID.encoded]

        let getConversationIDStringsResult = await getConversationIDStrings(for: userID)

        switch getConversationIDStringsResult {
        case var .success(conversationIDStrings):
            conversationIDStrings.append(conversationID.encoded)
            conversationIDStrings = conversationIDStrings.filter { !$0.isBangQualifiedEmpty }.unique

            let path = networking.config.paths.users
            if let exception = await networking.database.setValue(
                conversationIDStrings,
                forKey: "\(path)/\(userID)/\(User.SerializationKeys.conversations.rawValue)"
            ) {
                return exception.appending(extraParams: commonParams)
            }

        case let .failure(exception):
            return exception.appending(extraParams: commonParams)
        }

        return nil
    }
}
