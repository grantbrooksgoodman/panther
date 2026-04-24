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
        case aiEnhancedTranslationsEnabled
        case badgeNumber
        case blockedUserIDs
        case conversationIDs = "openConversations"
        case isPenPalsParticipant
        case languageCode
        case lastSignedIn
        case messageRecipientConsentRequired
        case phoneNumber
        case previousLanguageCodes
        case pushTokens
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        let conversationIDs = (conversationIDs ?? .init()).map(\.encoded)
        return [
            Keys.id.rawValue: id,
            Keys.aiEnhancedTranslationsEnabled.rawValue: aiEnhancedTranslationsEnabled,
            Keys.blockedUserIDs.rawValue: blockedUserIDs ?? .bangQualifiedEmpty,
            Keys.conversationIDs.rawValue: conversationIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : conversationIDs,
            Keys.isPenPalsParticipant.rawValue: isPenPalsParticipant,
            Keys.languageCode.rawValue: languageCode,
            Keys.lastSignedIn.rawValue: Date.timestampFromOptional(date: lastSignedIn),
            Keys.messageRecipientConsentRequired.rawValue: messageRecipientConsentRequired,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.previousLanguageCodes.rawValue: previousLanguageCodes ?? .bangQualifiedEmpty,
            Keys.pushTokens.rawValue: pushTokens ?? .bangQualifiedEmpty,
        ]
    }

    // MARK: - Methods

    static func canDecode(from data: [String: Any]) -> Bool {
        @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter

        guard data[Keys.id.rawValue] is String,
              data[Keys.aiEnhancedTranslationsEnabled.rawValue] is Bool,
              data[Keys.blockedUserIDs.rawValue] is [String],
              let conversationIDStrings = data[Keys.conversationIDs.rawValue] as? [String],
              conversationIDStrings.isBangQualifiedEmpty || conversationIDStrings.allSatisfy({ ConversationID.canDecode(from: $0) }),
              data[Keys.isPenPalsParticipant.rawValue] is Bool,
              data[Keys.messageRecipientConsentRequired.rawValue] is Bool,
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              PhoneNumber.canDecode(from: encodedPhoneNumber),
              data[Keys.languageCode.rawValue] is String,
              let lastSignedInString = data[Keys.lastSignedIn.rawValue] as? String,
              timestampDateFormatter.date(from: lastSignedInString) != nil,
              data[Keys.previousLanguageCodes.rawValue] is [String],
              data[Keys.pushTokens.rawValue] is [String] else { return false }

        return true
    }

    static func decode(from data: [String: Any]) async -> Callback<User, Exception> {
        @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter

        guard let id = data[Keys.id.rawValue] as? String,
              let aiEnhancedTranslationsEnabled = data[Keys.aiEnhancedTranslationsEnabled.rawValue] as? Bool,
              let blockedUserIDs = data[Keys.blockedUserIDs.rawValue] as? [String],
              let conversationIDStrings = data[Keys.conversationIDs.rawValue] as? [String],
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              let isPenPalsParticipant = data[Keys.isPenPalsParticipant.rawValue] as? Bool,
              let languageCode = data[Keys.languageCode.rawValue] as? String,
              let lastSignedInString = data[Keys.lastSignedIn.rawValue] as? String,
              let lastSignedIn = timestampDateFormatter.date(from: lastSignedInString),
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

        let decodeResults = await conversationIDStrings
            .filter { !$0.isBangQualifiedEmpty }
            .parallelMap {
                await ConversationID.decode(from: $0)
            }

        var conversationIDs = [ConversationID]()
        switch decodeResults {
        case let .success(decodedConversationIDs): conversationIDs = decodedConversationIDs
        case let .failure(exception): return .failure(exception)
        }

        guard let phoneNumber else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        return .success(.init(
            id,
            aiEnhancedTranslationsEnabled: aiEnhancedTranslationsEnabled,
            blockedUserIDs: blockedUserIDs.isBangQualifiedEmpty ? nil : blockedUserIDs,
            conversationIDs: conversationIDs.isEmpty ? nil : conversationIDs,
            isPenPalsParticipant: isPenPalsParticipant,
            languageCode: languageCode,
            lastSignedIn: lastSignedIn,
            messageRecipientConsentRequired: messageRecipientConsentRequired,
            phoneNumber: phoneNumber,
            previousLanguageCodes: previousLanguageCodes.isBangQualifiedEmpty ? nil : previousLanguageCodes,
            pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
        ))
    }
}
