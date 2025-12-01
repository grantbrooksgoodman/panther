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

    typealias T = User
    private typealias Keys = SerializationKeys

    // MARK: - Types

    enum SerializationKeys: String {
        case id
        case badgeNumber
        case blockedUserIDs
        case conversationIDs = "openConversations"
        case isPenPalsParticipant
        case languageCode
        case messageRecipientConsentRequired
        case phoneNumber
        case previousLanguageCodes
        case pushTokens
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        let conversationIDs = (conversationIDs ?? .init()).map { $0.encoded }
        return [
            Keys.id.rawValue: id,
            Keys.blockedUserIDs.rawValue: blockedUserIDs ?? .bangQualifiedEmpty,
            Keys.conversationIDs.rawValue: conversationIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : conversationIDs,
            Keys.isPenPalsParticipant.rawValue: isPenPalsParticipant,
            Keys.languageCode.rawValue: languageCode,
            Keys.messageRecipientConsentRequired.rawValue: messageRecipientConsentRequired,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.previousLanguageCodes.rawValue: previousLanguageCodes ?? .bangQualifiedEmpty,
            Keys.pushTokens.rawValue: pushTokens ?? .bangQualifiedEmpty,
        ]
    }

    // MARK: - Methods

    static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.id.rawValue] is String,
              data[Keys.blockedUserIDs.rawValue] is [String],
              let conversationIDStrings = data[Keys.conversationIDs.rawValue] as? [String],
              conversationIDStrings.isBangQualifiedEmpty || conversationIDStrings.allSatisfy({ ConversationID.canDecode(from: $0) }),
              data[Keys.isPenPalsParticipant.rawValue] is Bool,
              data[Keys.messageRecipientConsentRequired.rawValue] is Bool,
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              PhoneNumber.canDecode(from: encodedPhoneNumber),
              data[Keys.languageCode.rawValue] is String,
              data[Keys.previousLanguageCodes.rawValue] is [String],
              data[Keys.pushTokens.rawValue] is [String] else { return false }

        return true
    }

    static func decode(from data: [String: Any]) async -> Callback<User, Exception> {
        guard let id = data[Keys.id.rawValue] as? String,
              let blockedUserIDs = data[Keys.blockedUserIDs.rawValue] as? [String],
              let conversationIDStrings = data[Keys.conversationIDs.rawValue] as? [String],
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              let isPenPalsParticipant = data[Keys.isPenPalsParticipant.rawValue] as? Bool,
              let languageCode = data[Keys.languageCode.rawValue] as? String,
              let messageRecipientConsentRequired = data[Keys.messageRecipientConsentRequired.rawValue] as? Bool,
              let previousLanguageCodes = data[Keys.previousLanguageCodes.rawValue] as? [String],
              let pushTokens = data[Keys.pushTokens.rawValue] as? [String] else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
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
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        return .success(.init(
            id,
            blockedUserIDs: blockedUserIDs.isBangQualifiedEmpty ? nil : blockedUserIDs,
            conversationIDs: conversationIDs.isEmpty ? nil : conversationIDs,
            isPenPalsParticipant: isPenPalsParticipant,
            languageCode: languageCode,
            messageRecipientConsentRequired: messageRecipientConsentRequired,
            phoneNumber: phoneNumber,
            previousLanguageCodes: previousLanguageCodes.isBangQualifiedEmpty ? nil : previousLanguageCodes,
            pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
        ))
    }
}
