//
//  User+Updatable.swift
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

extension User: Updatable {
    // MARK: - Type Aliases

    typealias SerializationKey = User.SerializationKeys
    typealias U = User

    // MARK: - Properties

    var updatableKeys: [SerializationKeys] {
        [
            .blockedUserIDs,
            .conversationIDs,
            .isPenPalsParticipant,
            .messageRecipientConsentRequired,
            .previousLanguageCodes,
            .pushTokens,
        ]
    }

    // MARK: - Modify Key

    func modifyKey(_ key: SerializationKeys, withValue value: Any) -> User? {
        switch key {
        case .badgeNumber,
             .id,
             .languageCode,
             .phoneNumber:
            return nil

        case .blockedUserIDs:
            guard let value = value as? [String] else { return nil }
            return .init(
                id,
                blockedUserIDs: value.isBangQualifiedEmpty ? nil : value,
                conversationIDs: conversationIDs,
                isPenPalsParticipant: isPenPalsParticipant,
                languageCode: languageCode,
                messageRecipientConsentRequired: messageRecipientConsentRequired,
                phoneNumber: phoneNumber,
                previousLanguageCodes: previousLanguageCodes,
                pushTokens: pushTokens
            )

        case .conversationIDs:
            #warning("Make sure this works when the array is empty.")
            guard let value = value as? [ConversationID] else { return nil }
            return .init(
                id,
                blockedUserIDs: blockedUserIDs,
                conversationIDs: value,
                isPenPalsParticipant: isPenPalsParticipant,
                languageCode: languageCode,
                messageRecipientConsentRequired: messageRecipientConsentRequired,
                phoneNumber: phoneNumber,
                previousLanguageCodes: previousLanguageCodes,
                pushTokens: pushTokens
            )

        case .isPenPalsParticipant:
            guard let value = value as? Bool else { return nil }
            return .init(
                id,
                blockedUserIDs: blockedUserIDs,
                conversationIDs: conversationIDs,
                isPenPalsParticipant: value,
                languageCode: languageCode,
                messageRecipientConsentRequired: messageRecipientConsentRequired,
                phoneNumber: phoneNumber,
                previousLanguageCodes: previousLanguageCodes,
                pushTokens: pushTokens
            )

        case .messageRecipientConsentRequired:
            guard let value = value as? Bool else { return nil }
            return .init(
                id,
                blockedUserIDs: blockedUserIDs,
                conversationIDs: conversationIDs,
                isPenPalsParticipant: value,
                languageCode: languageCode,
                messageRecipientConsentRequired: value,
                phoneNumber: phoneNumber,
                previousLanguageCodes: previousLanguageCodes,
                pushTokens: pushTokens
            )

        case .previousLanguageCodes:
            guard let value = value as? [String] else { return nil }
            return .init(
                id,
                blockedUserIDs: blockedUserIDs,
                conversationIDs: conversationIDs,
                isPenPalsParticipant: isPenPalsParticipant,
                languageCode: languageCode,
                messageRecipientConsentRequired: messageRecipientConsentRequired,
                phoneNumber: phoneNumber,
                previousLanguageCodes: value.isBangQualifiedEmpty ? nil : value,
                pushTokens: pushTokens
            )

        case .pushTokens:
            guard let value = value as? [String] else { return nil }
            return .init(
                id,
                blockedUserIDs: blockedUserIDs,
                conversationIDs: conversationIDs,
                isPenPalsParticipant: isPenPalsParticipant,
                languageCode: languageCode,
                messageRecipientConsentRequired: messageRecipientConsentRequired,
                phoneNumber: phoneNumber,
                previousLanguageCodes: previousLanguageCodes,
                pushTokens: value.isBangQualifiedEmpty ? nil : value
            )
        }
    }

    // MARK: - Upate Value

    func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<User, Exception> {
        @Dependency(\.networking) var networking: NetworkServices

        guard updatableKeys.contains(key) else {
            return .failure(.Networking.notUpdatable(key: key, .init(sender: self)))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.Networking.typeMismatch(key: key, .init(sender: self)))
        }

        let userKeyPath = "\(NetworkPath.users.rawValue)/\(id)/"
        let valueKeyPath = userKeyPath + key.rawValue

        if let serializable = value as? any Serializable {
            if let exception = await networking.database.setValue(serializable.encoded, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if let serializable = value as? [any Serializable] {
            let encoded = serializable.map { $0.encoded }
            if let exception = await networking.database.setValue(
                encoded.isEmpty ? Array.bangQualifiedEmpty : encoded,
                forKey: valueKeyPath
            ) {
                return .failure(exception)
            }
        } else if networking.database.isEncodable(value) {
            if let exception = await networking.database.setValue(value, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else {
            return .failure(.Networking.notSerialized(data: [key.rawValue: value], .init(sender: self)))
        }

        return .success(updated)
    }
}
