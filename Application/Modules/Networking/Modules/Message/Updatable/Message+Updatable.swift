//
//  Message+Updatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

extension Message: Updatable {
    // MARK: - Type Aliases

    public typealias SerializationKey = Message.SerializationKeys
    public typealias U = Message

    // MARK: - Properties

    public var updatableKeys: [SerializationKeys] {
        [
            .hasAudioComponent,
            .readDate,
        ]
    }

    // MARK: - Methods

    public func modifyKey(_ key: SerializationKeys, withValue value: Any) -> Message? {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        switch key {
        case .fromAccountID,
             .id,
             .sentDate,
             .translations:
            return nil

        case .hasAudioComponent:
            guard let value = value as? String else { return nil }
            return .init(
                id,
                fromAccountID: fromAccountID,
                hasAudioComponent: value == "true" ? true : false,
                audioComponents: audioComponents,
                translations: translations,
                readDate: readDate,
                sentDate: sentDate
            )

        case .readDate:
            guard let value = value as? String else { return nil }
            return .init(
                id,
                fromAccountID: fromAccountID,
                hasAudioComponent: hasAudioComponent,
                audioComponents: audioComponents,
                translations: translations,
                readDate: dateFormatter.date(from: value) ?? nil,
                sentDate: sentDate
            )
        }
    }

    public func updateValue(_ value: Any, forKey key: SerializationKeys) async -> Callback<Message, Exception> {
        @Dependency(\.networking) var networking: Networking

        guard updatableKeys.contains(key) else {
            return .failure(.notUpdatable(key: key, [self, #file, #function, #line]))
        }

        guard let updated = modifyKey(key, withValue: value) else {
            return .failure(.typeMismatch(key: key, [self, #file, #function, #line]))
        }

        let messageKeyPath = "\(networking.config.paths.messages)/\(id)/"

        let valueKeyPath = messageKeyPath + key.rawValue
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

        return .success(updated)
    }
}
