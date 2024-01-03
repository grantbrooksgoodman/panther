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
        case compressedHash = "hash"
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
            Keys.compressedHash.rawValue: compressedHash,
            Keys.conversations.rawValue: conversationIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDs,
            Keys.languageCode.rawValue: languageCode,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.pushTokens.rawValue: pushTokens ?? .bangQualifiedEmpty,
        ]
    }

    // MARK: - Methods

    // swiftlint:disable:next function_body_length
    public static func decode(from data: [String: Any]) async -> Callback<User, Exception> {
        @Dependency(\.clientSessionService.conversation) var conversationSession: ConversationSessionService
        @Dependency(\.networking.services) var networkServices: NetworkServices

        guard let id = data[Keys.id.rawValue] as? String,
              let conversationIDStrings = data[Keys.conversations.rawValue] as? [String],
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              let languageCode = data[Keys.languageCode.rawValue] as? String,
              let pushTokens = data[Keys.pushTokens.rawValue] as? [String] else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        var userID: UserID?
        let decodeUserIDResult = await UserID.decode(from: id)

        switch decodeUserIDResult {
        case let .success(decodedUserID):
            userID = decodedUserID

        case let .failure(exception):
            return .failure(exception)
        }

        guard let userID else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        if let archivedUser = networkServices.user.archive.getValue(id: userID) {
            Logger.log(
                .init(
                    "Successfully retrieved user from archive.",
                    extraParams: ["UserIDKey": userID.key,
                                  "UserIDHash": userID.hash],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .user
            )

            return .success(archivedUser)
        }

        var phoneNumber: PhoneNumber?
        let decodePhoneNumberResult = await PhoneNumber.decode(from: encodedPhoneNumber)

        switch decodePhoneNumberResult {
        case let .success(decodedPhoneNumber):
            phoneNumber = decodedPhoneNumber
        case let .failure(exception):
            return .failure(exception)
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

        guard let phoneNumber else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        guard !conversationIDs.isEmpty else {
            let decoded: User = .init(
                userID,
                conversations: nil,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
            )
            networkServices.user.archive.addValue(decoded)
            return .success(decoded)
        }

        var conversationsNeedingFetch = [ConversationID]()
        var conversationsNeedingUpdate = [Conversation]()
        var decodedConversations = [Conversation]()

        for conversationID in conversationIDs {
            if let value = networkServices.conversation.archive.getValue(id: conversationID) {
                decodedConversations.append(value)
            } else if let value = networkServices.conversation.archive.getValue(idKey: conversationID.key) {
                conversationsNeedingUpdate.append(value)
            } else {
                conversationsNeedingFetch.append(conversationID)
            }
        }

        Logger.log(
            // swiftlint:disable:next line_length
            "Conversations needing update: \(conversationsNeedingUpdate.count)\nConversations needing fetch: \(conversationsNeedingFetch.count)\nDecoded conversations: \(decodedConversations.count)",
            domain: .user,
            metadata: [self, #file, #function, #line]
        )

        if conversationsNeedingFetch.isEmpty,
           conversationsNeedingUpdate.isEmpty {
            let sortedConversations = decodedConversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
            let decoded: User = .init(
                userID,
                conversations: sortedConversations.isEmpty ? nil : sortedConversations,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
            )
            networkServices.user.archive.addValue(decoded)
            return .success(decoded)
        }

        for conversation in conversationsNeedingUpdate {
            let updateConversationResult = await conversationSession.updateConversation(conversation)

            switch updateConversationResult {
            case let .success(updatedConversation):
                decodedConversations.removeAll(where: { $0.id.key == updatedConversation.id.key })
                decodedConversations.append(updatedConversation)
                networkServices.conversation.archive.addValue(updatedConversation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        func decodedUser(_ conversations: [Conversation]) -> User {
            let decoded: User = .init(
                userID,
                conversations: conversations.isEmpty ? nil : conversations,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
            )
            networkServices.user.archive.addValue(decoded)
            return decoded
        }

        guard !conversationsNeedingFetch.isEmpty else {
            guard decodedConversations.count == conversationIDs.count else {
                return .failure(.init("Mismatched ratio returned.", metadata: [self, #file, #function, #line]))
            }

            return .success(decodedUser(decodedConversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })))
        }

        let getConversationsResult = await networkServices.conversation.getConversations(idKeys: conversationsNeedingFetch.map(\.key))

        switch getConversationsResult {
        case let .success(conversations):
            decodedConversations.append(contentsOf: conversations)

            guard decodedConversations.count == conversationIDs.count else {
                return .failure(.init("Mismatched ratio returned.", metadata: [self, #file, #function, #line]))
            }

            return .success(decodedUser(decodedConversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })))

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
