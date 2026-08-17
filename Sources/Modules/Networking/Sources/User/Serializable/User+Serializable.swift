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

    /// The serializable keys for encoding and decoding a user.
    enum SerializableKey: String {
        case id
        case aiEnhancedTranslationsEnabled
        case badgeNumber
        case blockedUserIDs
        case conversationIDs = "openConversations"
        case deviceID
        case isPenPalsParticipant
        case languageCode
        case messageRecipientConsentRequired
        case phoneNumber
        case previousLanguageCodes
        case pushTokens
    }

    // MARK: - Properties

    /// The serialized representation of the user.
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
            Keys.deviceID.rawValue: deviceID,
            Keys.isPenPalsParticipant.rawValue: isPenPalsParticipant,
            Keys.languageCode.rawValue: languageCode,
            Keys.messageRecipientConsentRequired.rawValue: messageRecipientConsentRequired,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.previousLanguageCodes.rawValue: previousLanguageCodes ?? .bangQualifiedEmpty,
            Keys.pushTokens.rawValue: encodedPushTokens,
        ]
    }

    // MARK: - Init

    /// Creates a user by decoding the given serialized data.
    ///
    /// - Parameter data: The serialized user data.
    ///
    /// - Throws: An `Exception` if the data cannot be decoded.
    init(
        from data: [String: Any]
    ) async throws(Exception) {
        guard let id = data[Keys.id.rawValue] as? String,
              let aiEnhancedTranslationsEnabled = data[Keys.aiEnhancedTranslationsEnabled.rawValue] as? Bool,
              let deviceID = data[Keys.deviceID.rawValue] as? String,
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              let isPenPalsParticipant = data[Keys.isPenPalsParticipant.rawValue] as? Bool,
              let languageCode = data[Keys.languageCode.rawValue] as? String,
              let messageRecipientConsentRequired = data[Keys.messageRecipientConsentRequired.rawValue] as? Bool,
              let previousLanguageCodes = data[Keys.previousLanguageCodes.rawValue] as? [String] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let phoneNumber = try await PhoneNumber(from: encodedPhoneNumber)

        // Dictionaries carry no order; sort map-derived arrays so
        // re-decodes of identical data compare equal.
        let blockedUserIDs: [String] = if let map = data[
            Keys.blockedUserIDs.rawValue
        ] as? [String: Any] {
            map.keys.sorted()
        } else {
            []
        }

        let conversationIDs: [ConversationID] = if let map = data[
            Keys.conversationIDs.rawValue
        ] as? [String: String] {
            map
                .map {
                    ConversationID(
                        key: $0.key,
                        hash: $0.value
                    )
                }
                .sorted { $0.key < $1.key }
        } else {
            []
        }

        let pushTokens: [String] = if let map = data[
            Keys.pushTokens.rawValue
        ] as? [String: Any] {
            map.keys.sorted()
        } else {
            []
        }

        self.init(
            id,
            aiEnhancedTranslationsEnabled: aiEnhancedTranslationsEnabled,
            blockedUserIDs: blockedUserIDs.isBangQualifiedEmpty ? nil : blockedUserIDs,
            conversationIDs: conversationIDs.isEmpty ? nil : conversationIDs,
            deviceID: deviceID,
            isPenPalsParticipant: isPenPalsParticipant,
            languageCode: languageCode,
            messageRecipientConsentRequired: messageRecipientConsentRequired,
            phoneNumber: phoneNumber,
            previousLanguageCodes: previousLanguageCodes.isBangQualifiedEmpty ? nil : previousLanguageCodes,
            pushTokens: pushTokens.isBangQualifiedEmpty ? nil : pushTokens
        )
    }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether a user can be decoded from the given data.
    ///
    /// - Parameter data: The serialized user data.
    ///
    /// - Returns: `true` if a user can be decoded; otherwise, `false`.
    static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.id.rawValue] is String,
              data[Keys.aiEnhancedTranslationsEnabled.rawValue] is Bool,
              data[Keys.blockedUserIDs.rawValue] is [String: Any] ||
              data[Keys.blockedUserIDs.rawValue] == nil,
              data[Keys.conversationIDs.rawValue] is [String: String] ||
              data[Keys.conversationIDs.rawValue] == nil,
              data[Keys.deviceID.rawValue] is String,
              data[Keys.isPenPalsParticipant.rawValue] is Bool,
              data[Keys.messageRecipientConsentRequired.rawValue] is Bool,
              let encodedPhoneNumber = data[Keys.phoneNumber.rawValue] as? [String: Any],
              PhoneNumber.canDecode(from: encodedPhoneNumber),
              data[Keys.languageCode.rawValue] is String,
              data[Keys.previousLanguageCodes.rawValue] is [String],
              data[Keys.pushTokens.rawValue] is [String: Any] ||
              data[Keys.pushTokens.rawValue] == nil else { return false }

        return true
    }
}
