//
//  Reaction+Serializable.swift
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

extension Reaction: Serializable {
    // MARK: - Type Aliases

    private typealias Keys = SerializableKey

    // MARK: - Types

    private enum SerializableKey: String {
        case style
        case userID
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        [
            Keys.style.rawValue: style.encodedValue,
            Keys.userID.rawValue: userID,
        ]
    }

    // MARK: - Init

    init(
        from data: [String: Any] // swiftformat:disable all
    ) async throws(Exception) { // swiftformat:enable all
        guard let encodedStyle = data[Keys.style.rawValue] as? String,
              let style = Reaction.Style(encodedValue: encodedStyle),
              let userID = data[Keys.userID.rawValue] as? String else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self = .init(
            style,
            userID: userID
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        guard let encodedStyle = data[Keys.style.rawValue] as? String,
              Reaction.Style(encodedValue: encodedStyle) != nil,
              data[Keys.userID.rawValue] is String else { return false }
        return true
    }
}
