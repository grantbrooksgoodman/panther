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
            .conversations,
            .pushTokens,
        ]
    }

    // MARK: - Methods

    public func modifyKey(_ key: SerializationKeys, withValue value: Any) -> User? {
        switch key {
        case .compressedHash,
             .id,
             .languageCode,
             .phoneNumber:
            return nil

        case .conversations:
            guard let value = value as? [Conversation] else { return nil }
            return updateIDHash(.init(
                id,
                conversations: value,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: pushTokens
            ))

        case .pushTokens:
            guard let value = value as? [String] else { return nil }
            return updateIDHash(.init(
                id,
                conversations: conversations,
                languageCode: languageCode,
                phoneNumber: phoneNumber,
                pushTokens: value
            ))
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

        networking.services.user.archive.addValue(updated)

        let userKeyPath = "\(networking.config.paths.users)/\(id.key)/"
        let valueKeyPath = userKeyPath + key.rawValue

        if key == .conversations,
           let conversations = value as? [Conversation] {
            if let exception = await networking.database.setValue(conversations.map(\.id.encoded), forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if let serializable = value as? any Serializable {
            if let exception = await networking.database.setValue(serializable.encoded, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if networking.database.isEncodable(value) {
            if let exception = await networking.database.setValue(value, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else {
            return .failure(.notSerialized(data: [key.rawValue: value], [self, #file, #function, #line]))
        }

        guard updated.compressedHash != compressedHash else {
            return .success(updated)
        }

        let hashPath = userKeyPath + SerializationKeys.compressedHash.rawValue
        if let exception = await networking.database.setValue(updated.compressedHash, forKey: hashPath) {
            return .failure(exception)
        }

        return .success(updated)
    }

    private func updateIDHash(_ user: User) -> User {
        .init(
            .init(key: user.id.key, hash: user.compressedHash),
            conversations: user.conversations,
            languageCode: user.languageCode,
            phoneNumber: user.phoneNumber,
            pushTokens: user.pushTokens
        )
    }
}
