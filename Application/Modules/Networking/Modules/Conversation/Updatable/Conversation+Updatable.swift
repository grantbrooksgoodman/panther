//
//  Conversation+Updatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

extension Conversation: Updatable {
    // MARK: - Type Aliases

    public typealias SerializationKey = Conversation.SerializationKeys
    public typealias U = Conversation

    // MARK: - Properties

    public var updatableKeys: [SerializationKeys] {
        [
            .lastModifiedDate,
            .messages,
            .participants,
        ]
    }

    // MARK: - Methods

    public func modifyKey(_ key: SerializationKeys, withValue value: Any) -> Conversation? {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        switch key {
        case .compressedHash,
             .id:
            return nil

        case .lastModifiedDate:
            guard let value = value as? String else { return nil }
            return updateHashID(.init(
                id,
                messages: messages,
                lastModifiedDate: dateFormatter.date(from: value) ?? lastModifiedDate,
                participants: participants,
                users: users
            ))

        case .messages:
            guard let value = value as? [Message] else { return nil }
            return updateHashID(.init(
                id,
                messages: value,
                lastModifiedDate: lastModifiedDate,
                participants: participants,
                users: users
            ))

        case .participants:
            guard let value = value as? [Participant] else { return nil }
            return updateHashID(.init(
                id,
                messages: messages,
                lastModifiedDate: lastModifiedDate,
                participants: value,
                users: users
            ))
        }
    }

    public func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: Networking

        guard updatableKeys.contains(key) else {
            return .failure(.notUpdatable(key: key, [self, #file, #function, #line]))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        if networking.services.conversation.archive.getValue(idKey: updated.id.key) != nil {
            networking.services.conversation.archive.addValue(updated)
        }

        let conversationKeyPath = "\(networking.config.paths.conversations)/\(id.key)/"
        let valueKeyPath = conversationKeyPath + key.rawValue

        guard key != .messages else {
            guard let messages = value as? [Message] else {
                return .failure(.init(metadata: [self, #file, #function, #line]))
            }

            if let exception = await networking.database.setValue(messages.map(\.id), forKey: valueKeyPath) {
                return .failure(exception)
            }

            return .success(updated)
        }

        if let serializable = value as? any Serializable {
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

        let hashPath = conversationKeyPath + SerializationKeys.compressedHash.rawValue
        if let exception = await networking.database.setValue(updated.compressedHash, forKey: hashPath) {
            return .failure(exception)
        }

        let paths = participants.map(\.userID).reduce(into: [String]()) { partialResult, userID in
            partialResult.append("\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.conversations.rawValue)")
        }

        for path in paths {
            let getValuesResult = await networking.database.getValues(at: path)

            switch getValuesResult {
            case let .success(values):
                guard var array = values as? [String] else {
                    return .failure(.init(
                        "Failed to typecast values to array.",
                        metadata: [self, #file, #function, #line]
                    ))
                }

                guard let index = array.firstIndex(where: { $0.hasPrefix(id.key) }) else {
                    return .failure(.init(
                        "Failed to get conversation index for user.",
                        metadata: [self, #file, #function, #line]
                    ))
                }

                array.removeAll(where: { $0.hasPrefix(id.key) })
                array.insert(updated.id.encoded, at: index)

                if let exception = await networking.database.setValue(array, forKey: path) {
                    return .failure(exception)
                }

            case let .failure(exception):
                return .failure(exception)
            }
        }

        return .success(updated)
    }

    private func updateHashID(_ conversation: Conversation) -> Conversation {
        var modified = conversation
        modified = .init(
            .init(key: modified.id.key, hash: modified.compressedHash),
            messages: modified.messages,
            lastModifiedDate: modified.lastModifiedDate,
            participants: modified.participants,
            users: modified.users
        )

        return modified
    }
}
