//
//  UpdatableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol Updatable {
    // MARK: - Associated Types

    associatedtype SerializationKey
    associatedtype U: Serializable

    // MARK: - Properties

    var updatableKeys: [SerializationKey] { get }

    // MARK: - Methods

    func modifyKey(_ key: SerializationKey, withValue value: Any) -> U?
    func updateValue(_ value: Any, forKey key: SerializationKey) async -> Callback<U, Exception>
}

public extension Exception {
    static func notSerialized(
        data: [String: Any],
        _ metadata: [Any]
    ) -> Exception {
        return .init(
            "Type value must be serialized.",
            extraParams: ["Data": data],
            metadata: metadata
        )
    }

    static func notUpdatable(
        key: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "The specified serialization key is not updatable.",
            extraParams: ["Key": key],
            metadata: metadata
        )
    }

    static func typeMismatch(
        key: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Type mismatch for serialization key.",
            extraParams: ["Key": key],
            metadata: metadata
        )
    }
}
