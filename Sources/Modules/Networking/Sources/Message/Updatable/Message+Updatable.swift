//
//  Message+Updatable.swift
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

extension Message: Updatable {
    // MARK: - Type Aliases

    typealias SerializationKey = Message.SerializationKeys
    typealias U = Message

    // MARK: - Properties

    var updatableKeys: [SerializationKeys] { [.readReceipts] }

    // MARK: - Modify Key

    func modifyKey(_ key: SerializationKeys, withValue value: Any) -> Message? {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        switch key {
        case .contentType,
             .fromAccountID,
             .id,
             .sentDate,
             .translationReferences:
            return nil

        case .readReceipts:
            guard let value = value as? [ReadReceipt] else { return nil }
            return .init(
                id,
                fromAccountID: fromAccountID,
                contentType: contentType,
                richContent: richContent,
                translationReferences: translationReferences,
                translations: translations,
                readReceipts: value.isEmpty ? nil : value,
                sentDate: sentDate
            )
        }
    }

    // MARK: - Update Value

    func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<Message, Exception> {
        @Dependency(\.networking) var networking: NetworkServices

        guard updatableKeys.contains(key) else {
            return .failure(.Networking.notUpdatable(key: key, .init(sender: self)))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.Networking.typeMismatch(key: key, .init(sender: self)))
        }

        let messageKeyPath = "\(NetworkPath.messages.rawValue)/\(id)/"

        let valueKeyPath = messageKeyPath + key.rawValue
        if let serializable = value as? any Serializable {
            if let exception = await networking.database.setValue(serializable.encoded, forKey: valueKeyPath) {
                return .failure(exception)
            }
        } else if let serializable = value as? [any Serializable] {
            // swiftformat:disable all
            let encoded = serializable.map { $0.encoded } // swiftformat:enable all
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
