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
            return updateIDHash(.init(
                id,
                messageIDs: messageIDs,
                messages: messages,
                lastModifiedDate: dateFormatter.date(from: value) ?? lastModifiedDate,
                participants: participants,
                users: users
            ))

        case .messages:
            guard let value = value as? [Message] else { return nil }
            return updateIDHash(.init(
                id,
                messageIDs: value.map(\.id).unique,
                messages: value.uniquedByID,
                lastModifiedDate: lastModifiedDate,
                participants: participants,
                users: users
            ))

        case .participants:
            guard let value = value as? [Participant] else { return nil }
            return updateIDHash(.init(
                id,
                messageIDs: messageIDs,
                messages: messages,
                lastModifiedDate: lastModifiedDate,
                participants: value,
                users: users
            ))
        }
    }

    public func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<Conversation, Exception> {
        @Dependency(\.networking) var networking: Networking
        @Dependency(\.clientSessionService.user) var userSession: UserSessionService

        guard updatableKeys.contains(key) else {
            return .failure(.notUpdatable(key: key, [self, #file, #function, #line]))
        }

        if let exception = await setUsers() {
            return .failure(exception)
        }

        guard var users else {
            return .failure(.init(
                "Failed to set users on conversation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        let conversationKeyPath = "\(networking.config.paths.conversations)/\(id.key)/"
        let valueKeyPath = conversationKeyPath + key.rawValue

        if key == .messages,
           let messages = value as? [Message] {
            if let exception = await networking.database.setValue(messages.map(\.id), forKey: valueKeyPath) {
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

        let hashPath = conversationKeyPath + SerializationKeys.compressedHash.rawValue
        if let exception = await networking.database.setValue(updated.compressedHash, forKey: hashPath) {
            return .failure(exception)
        }

        if let currentUser = userSession.currentUser {
            users.append(currentUser)
        }

        for user in users {
            guard var conversationIDs = user.conversationIDs,
                  let index = conversationIDs.firstIndex(where: { $0.key == updated.id.key }) else { continue }

            conversationIDs.removeAll(where: { $0.key == updated.id.key })
            conversationIDs.insert(updated.id, at: index)

            let updateValueResult = await user.updateValue(conversationIDs, forKey: .conversationIDs)

            switch updateValueResult {
            case let .failure(exception):
                return .failure(exception)

            default: ()
            }
        }

        return .success(updated)
    }

    private func updateIDHash(_ conversation: Conversation) -> Conversation {
        .init(
            .init(key: conversation.id.key, hash: conversation.compressedHash),
            messageIDs: messageIDs,
            messages: conversation.messages,
            lastModifiedDate: conversation.lastModifiedDate,
            participants: conversation.participants,
            users: conversation.users
        )
    }
}
