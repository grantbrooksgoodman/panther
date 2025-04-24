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

    public typealias SerializationKey = User.SerializationKeys
    public typealias U = User

    // MARK: - Properties

    public var updatableKeys: [SerializationKeys] {
        [
            .blockedUserIDs,
            .conversationIDs,
            .isPenPalsParticipant,
            .messageRecipientConsentRequired,
            .pushTokens,
        ]
    }

    // MARK: - Modify Key

    public func modifyKey(_ key: SerializationKeys, withValue value: Any) -> User? {
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
                pushTokens: value.isBangQualifiedEmpty ? nil : value
            )
        }
    }

    // MARK: - Upate Value

    public func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<User, Exception> {
        @Dependency(\.networking) var networking: NetworkServices

        guard updatableKeys.contains(key) else {
            return .failure(.Networking.notUpdatable(key: key, [self, #file, #function, #line]))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.Networking.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        let userKeyPath = "\(NetworkPath.users.rawValue)/\(id)/"
        let valueKeyPath = userKeyPath + key.rawValue

        if let serializable = value as? any Serializable {
            if let exception = await networking.database.setValue(serializable.encoded, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if let serializable = value as? [any Serializable] {
            if let exception = await networking.database.setValue(serializable.map { $0.encoded }, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if networking.database.isEncodable(value) {
            if let exception = await networking.database.setValue(value, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else {
            return .failure(.Networking.notSerialized(data: [key.rawValue: value], [self, #file, #function, #line]))
        }

        return .success(updated)
    }
}
