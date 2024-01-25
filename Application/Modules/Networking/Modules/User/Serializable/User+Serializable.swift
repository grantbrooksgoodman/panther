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
        case badgeNumber
        case conversationIDs = "openConversations"
        case languageCode
        case phoneNumber
        case pushTokens
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        let conversationIDs = (conversationIDs ?? .init()).map { $0.encoded }
        return [
            Keys.id.rawValue: id,
            Keys.badgeNumber.rawValue: badgeNumber,
            Keys.conversationIDs.rawValue: conversationIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : conversationIDs,
            Keys.languageCode.rawValue: languageCode,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.pushTokens.rawValue: pushTokens ?? .bangQualifiedEmpty,
        ]
    }

    // MARK: - Methods

    public static func decode(from data: [String: Any]) async -> Callback<User, Exception> {
        guard let id = data[Keys.id.rawValue] as? String,
              let badgeNumber = data[Keys.badgeNumber.rawValue] as? Int,
              let conversationIDStrings = data[Keys.conversationIDs.rawValue] as? [String],
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              let languageCode = data[Keys.languageCode.rawValue] as? String,
              let pushTokens = data[Keys.pushTokens.rawValue] as? [String] else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
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

        return .success(.init(
            id,
            badgeNumber: badgeNumber,
            conversationIDs: conversationIDs.isEmpty ? nil : conversationIDs,
            languageCode: languageCode,
            phoneNumber: phoneNumber,
            pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
        ))
    }
}
