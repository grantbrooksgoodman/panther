//
//  User+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

extension User: Serializable {
    // MARK: - Type Aliases

    public typealias T = User
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case conversations = "openConversations"
        case languageCode
        case phoneNumber
        case pushTokens
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        let conversationIDs = (conversations ?? .init()).map { $0.id.encoded }
        return [
            Keys.id.rawValue: id,
            Keys.conversations.rawValue: conversationIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDs,
            Keys.languageCode.rawValue: languageCode,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.pushTokens.rawValue: pushTokens ?? .bangQualifiedEmpty,
        ]
    }

    // MARK: - Methods

    public static func decode(from data: [String: Any]) async -> Callback<User, Exception> {
        @Dependency(\.networking.services.conversation) var conversationService: ConversationService

        guard let id = data[Keys.id.rawValue] as? String,
              let conversationIDStrings = data[Keys.conversations.rawValue] as? [String],
              let languageCode = data[Keys.languageCode.rawValue] as? String,
              let phoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              let pushTokens = data[Keys.pushTokens.rawValue] as? [String] else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        var conversationIDs = [ConversationID]()
        for id in conversationIDStrings where !id.isBangQualifiedEmpty {
            let decodeResult = await ConversationID.decode(from: id)

            switch decodeResult {
            case let .success(conversationID):
                conversationIDs.append(conversationID)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        let decodeResult = await PhoneNumber.decode(from: phoneNumber)

        switch decodeResult {
        case let .success(phoneNumber):
            guard !conversationIDs.isEmpty else {
                let decoded: User = .init(
                    id,
                    conversations: nil,
                    languageCode: languageCode,
                    phoneNumber: phoneNumber,
                    pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
                )
                return .success(decoded)
            }

            var conversationsNeedingFetch = [ConversationID]()
            var decodedConversations = [Conversation]()

            for conversationID in conversationIDs {
                guard let value = conversationService.archive.getValue(id: conversationID) else {
                    conversationsNeedingFetch.append(conversationID)
                    continue
                }

                decodedConversations.append(value)
            }

            guard !conversationsNeedingFetch.isEmpty else {
                Logger.log(
                    "Conversation archive is up to date.",
                    domain: .conversation,
                    metadata: [self, #file, #function, #line]
                )

                let sortedConversations = decodedConversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
                let decoded: User = .init(
                    id,
                    conversations: sortedConversations.isEmpty ? nil : sortedConversations,
                    languageCode: languageCode,
                    phoneNumber: phoneNumber,
                    pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
                )
                return .success(decoded)
            }

            let getConversationsResult = await conversationService.getConversations(idKeys: conversationsNeedingFetch.map(\.key))

            switch getConversationsResult {
            case let .success(conversations):
                decodedConversations.append(contentsOf: conversations)

                let sortedConversations = decodedConversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
                let decoded: User = .init(
                    id,
                    conversations: sortedConversations.isEmpty ? nil : sortedConversations,
                    languageCode: languageCode,
                    phoneNumber: phoneNumber,
                    pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
                )
                return .success(decoded)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
