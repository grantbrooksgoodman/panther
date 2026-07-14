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
        var encodedBlockedUserIDs: Any = [String: Bool]()
        if let blockedUserIDs, !blockedUserIDs.isEmpty {
            var map = [String: Bool]()
            for userID in blockedUserIDs {
                map[userID] = true
            }

            encodedBlockedUserIDs = map
        }

        var encodedConversationIDs: Any = [String: String]()
        if let conversationIDs, !conversationIDs.isEmpty {
            var map = [String: String]()
            for conversationID in conversationIDs {
                map[conversationID.key] = conversationID.hash
            }

            encodedConversationIDs = map
        }

        var encodedPushTokens: Any = [String: Bool]()
        if let pushTokens, !pushTokens.isEmpty {
            var map = [String: Bool]()
            for token in pushTokens {
                map[token] = true
            }

            encodedPushTokens = map
        }

        return [
            Keys.id.rawValue: id,
            Keys.aiEnhancedTranslationsEnabled.rawValue: aiEnhancedTranslationsEnabled,
            Keys.blockedUserIDs.rawValue: encodedBlockedUserIDs,
            Keys.conversationIDs.rawValue: encodedConversationIDs,
            Keys.isPenPalsParticipant.rawValue: isPenPalsParticipant,
            Keys.languageCode.rawValue: languageCode,
            Keys.lastSignedIn.rawValue: Date.timestampFromOptional(date: lastSignedIn),
            Keys.messageRecipientConsentRequired.rawValue: messageRecipientConsentRequired,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.previousLanguageCodes.rawValue: previousLanguageCodes ?? .bangQualifiedEmpty,
            Keys.pushTokens.rawValue: encodedPushTokens,
        ]
    }

    // MARK: - Init

    init(
        from data: [String: Any]
    ) async throws(Exception) {
        @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter

        guard let id = data[Keys.id.rawValue] as? String,
              let aiEnhancedTranslationsEnabled = data[Keys.aiEnhancedTranslationsEnabled.rawValue] as? Bool,
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              let isPenPalsParticipant = data[Keys.isPenPalsParticipant.rawValue] as? Bool,
              let languageCode = data[Keys.languageCode.rawValue] as? String,
              let lastSignedInString = data[Keys.lastSignedIn.rawValue] as? String,
              let lastSignedIn = timestampDateFormatter.date(from: lastSignedInString),
              let messageRecipientConsentRequired = data[Keys.messageRecipientConsentRequired.rawValue] as? Bool,
              let previousLanguageCodes = data[Keys.previousLanguageCodes.rawValue] as? [String] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let phoneNumber = try await PhoneNumber(from: encodedPhoneNumber)

        // Dual-format decode: map (new) or array (legacy).
        let blockedUserIDs: [String]
        let rawBlockedUserIDs = data[Keys.blockedUserIDs.rawValue]
        if let map = rawBlockedUserIDs as? [String: Any] {
            blockedUserIDs = Array(map.keys)
        } else if let array = rawBlockedUserIDs as? [String] {
            blockedUserIDs = array
            if !blockedUserIDs.isBangQualifiedEmpty, !blockedUserIDs.isEmpty {
                SchemaMigration.flagLegacyBlockedUserIDs(userID: id)
            }
        } else {
            blockedUserIDs = []
        }

        // Dual-format decode: map (new) or array (legacy).
        let pushTokens: [String]
        let rawPushTokens = data[Keys.pushTokens.rawValue]
        if let map = rawPushTokens as? [String: Any] {
            pushTokens = Array(map.keys)
        } else if let array = rawPushTokens as? [String] {
            pushTokens = array
            if !pushTokens.isBangQualifiedEmpty, !pushTokens.isEmpty {
                SchemaMigration.flagLegacyPushTokens(userID: id)
            }
        } else {
            pushTokens = []
        }

        // Dual-format decode: map (new) or array (legacy).
        let conversationIDs: [ConversationID]
        let rawConversationIDs = data[Keys.conversationIDs.rawValue]
        if let map = rawConversationIDs as? [String: String] {
            conversationIDs = map.map { ConversationID(key: $0.key, hash: $0.value) }
        } else if let array = rawConversationIDs as? [String] {
            conversationIDs = try await array
                .filter { !$0.isBangQualifiedEmpty }
                .map { try await ConversationID(from: $0) }

            if !conversationIDs.isEmpty {
                SchemaMigration.flagLegacyConversationIDs(userID: id)
            }
        } else {
            conversationIDs = []
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

        let rawConversationIDs = data[Keys.conversationIDs.rawValue]
        let hasValidConversationIDs: Bool = {
            if rawConversationIDs is [String: String] { return true }
            if let array = rawConversationIDs as? [String] {
                return array.isBangQualifiedEmpty || array.allSatisfy { ConversationID.canDecode(from: $0) }
            }
            return rawConversationIDs == nil
        }()

        guard data[Keys.id.rawValue] is String,
              data[Keys.aiEnhancedTranslationsEnabled.rawValue] is Bool,
              data[Keys.blockedUserIDs.rawValue] is [String: Any] ||
              data[Keys.blockedUserIDs.rawValue] is [String],
              hasValidConversationIDs,
              data[Keys.isPenPalsParticipant.rawValue] is Bool,
              data[Keys.messageRecipientConsentRequired.rawValue] is Bool,
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              PhoneNumber.canDecode(from: encodedPhoneNumber),
              data[Keys.languageCode.rawValue] is String,
              let lastSignedInString = data[Keys.lastSignedIn.rawValue] as? String,
              timestampDateFormatter.date(from: lastSignedInString) != nil,
              data[Keys.previousLanguageCodes.rawValue] is [String],
              data[Keys.pushTokens.rawValue] is [String: Any] ||
              data[Keys.pushTokens.rawValue] is [String] else { return false }

        return true
    }
}
