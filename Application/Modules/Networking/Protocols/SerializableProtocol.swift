//
//  SerializableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public protocol Serializable {
    // MARK: - Associated Types

    associatedtype T
    associatedtype Representation

    // MARK: - Properties

    var encoded: Representation { get }

    // MARK: - Methods

    static func canDecode(from data: Representation) -> Bool
    static func decode(from data: Representation) async -> Callback<T, Exception>
}

public extension Exception {
    static func decodingFailed(
        data: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Decoding failed.",
            extraParams: ["Data": data],
            metadata: metadata
        )
    }
}
