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
                messages: messages,
                lastModifiedDate: dateFormatter.date(from: value) ?? lastModifiedDate,
                participants: participants,
                users: users
            ))

        case .messages:
            guard let value = value as? [Message] else { return nil }
            return updateIDHash(.init(
                id,
                messages: value,
                lastModifiedDate: lastModifiedDate,
                participants: participants,
                users: users
            ))

        case .participants:
            guard let value = value as? [Participant] else { return nil }
            return updateIDHash(.init(
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
        @Dependency(\.clientSessionService.user) var userSession: UserSessionService

        guard var users else {
            if let exception = await setUsers() {
                return .failure(exception)
            }

            return await updateValue(value, forKey: key)
        }

        guard updatableKeys.contains(key) else {
            return .failure(.notUpdatable(key: key, [self, #file, #function, #line]))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        networking.services.conversation.archive.addValue(updated)

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
            guard var conversations = user.conversations,
                  let index = conversations.firstIndex(where: { $0.id.key == updated.id.key }) else { continue }

            conversations.removeAll(where: { $0.id.key == updated.id.key })
            conversations.insert(updated, at: index)

            let updateValueResult = await user.updateValue(conversations, forKey: .conversations)

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
            messages: conversation.messages,
            lastModifiedDate: conversation.lastModifiedDate,
            participants: conversation.participants,
            users: conversation.users
        )
    }
}
