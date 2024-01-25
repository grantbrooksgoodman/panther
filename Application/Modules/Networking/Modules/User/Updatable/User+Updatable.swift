//
//  User+Updatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

extension User: Updatable {
    // MARK: - Type Aliases

    public typealias SerializationKey = User.SerializationKeys
    public typealias U = User

    // MARK: - Properties

    public var updatableKeys: [SerializationKeys] {
        [
            .badgeNumber,
            .conversationIDs,
            .pushTokens,
        ]
    }

    // MARK: - Methods

    public func modifyKey(_ key: SerializationKeys, withValue value: Any) -> User? {
        switch key {
        case .id,
             .languageCode,
             .phoneNumber:
            return nil

        case .badgeNumber:
            guard let value = value as? Int else { return nil }
            return .init(
                id,
                badgeNumber: value,
                conversationIDs: conversationIDs,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: pushTokens
            )

        case .conversationIDs:
            #warning("Make sure this works when the array is empty.")
            guard let value = value as? [ConversationID] else { return nil }
            return .init(
                id,
                badgeNumber: badgeNumber,
                conversationIDs: value,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: pushTokens
            )

        case .pushTokens:
            guard let value = value as? [String] else { return nil }
            return .init(
                id,
                badgeNumber: badgeNumber,
                conversationIDs: conversationIDs,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: value.isBangQualifiedEmpty ? nil : value
            )
        }
    }

    public func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<User, Exception> {
        @Dependency(\.networking) var networking: Networking

        guard updatableKeys.contains(key) else {
            return .failure(.notUpdatable(key: key, [self, #file, #function, #line]))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        let userKeyPath = "\(networking.config.paths.users)/\(id)/"
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
            return .failure(.notSerialized(data: [key.rawValue: value], [self, #file, #function, #line]))
        }

        return .success(updated)
    }
}
