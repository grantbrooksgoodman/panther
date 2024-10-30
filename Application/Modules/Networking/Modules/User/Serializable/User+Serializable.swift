//
//  User+Serializable.swift
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

extension User: Serializable {
    // MARK: - Type Aliases

    public typealias T = User
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case badgeNumber
        case blockedUserIDs
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
            Keys.blockedUserIDs.rawValue: blockedUserIDs ?? .bangQualifiedEmpty,
            Keys.conversationIDs.rawValue: conversationIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : conversationIDs,
            Keys.languageCode.rawValue: languageCode,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.pushTokens.rawValue: pushTokens ?? .bangQualifiedEmpty,
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.id.rawValue] as? String != nil,
              data[Keys.blockedUserIDs.rawValue] as? [String] != nil,
              let conversationIDStrings = data[Keys.conversationIDs.rawValue] as? [String],
              conversationIDStrings.allSatisfy({ ConversationID.canDecode(from: $0) }) || conversationIDStrings == ["!"],
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              PhoneNumber.canDecode(from: encodedPhoneNumber),
              data[Keys.languageCode.rawValue] as? String != nil,
              data[Keys.pushTokens.rawValue] as? [String] != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<User, Exception> {
        guard let id = data[Keys.id.rawValue] as? String,
              let blockedUserIDs = data[Keys.blockedUserIDs.rawValue] as? [String],
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
            blockedUserIDs: blockedUserIDs.isBangQualifiedEmpty ? nil : blockedUserIDs,
            conversationIDs: conversationIDs.isEmpty ? nil : conversationIDs,
            languageCode: languageCode,
            phoneNumber: phoneNumber,
            pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
        ))
    }
}
