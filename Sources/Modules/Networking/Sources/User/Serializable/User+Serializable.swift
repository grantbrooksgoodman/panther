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

    private typealias Keys = SerializableKey

    // MARK: - Types

    enum SerializableKey: String {
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

    // MARK: - Init

    convenience init(
        from data: [String: Any] // swiftformat:disable all
    ) async throws(Exception) { // swiftformat:enable all
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
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let phoneNumber = try await PhoneNumber(from: encodedPhoneNumber)
        let conversationIDs = try await conversationIDStrings
            .filter { !$0.isBangQualifiedEmpty }
            .parallelMap {
                try await ConversationID(from: $0)
            }

        self.init(
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
        )
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
}
