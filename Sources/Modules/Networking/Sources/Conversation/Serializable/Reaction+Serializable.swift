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

    /// The serializable keys for encoding and decoding a reaction.
    enum SerializableKey: String {
        case style
        case userID
    }

    // MARK: - Properties

    /// The serialized representation of the reaction.
    var encoded: [String: Any] {
        [
            Keys.style.rawValue: style.encodedValue,
            Keys.userID.rawValue: userID,
        ]
    }

    // MARK: - Init

    /// Creates a reaction by decoding the given serialized data.
    ///
    /// - Parameter data: The serialized reaction data.
    ///
    /// - Throws: An `Exception` if the data cannot be decoded.
    init(
        from data: [String: Any]
    ) async throws(Exception) {
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

    /// Returns a Boolean value that indicates whether a reaction can be decoded from the given
    /// data.
    ///
    /// - Parameter data: The serialized reaction data.
    ///
    /// - Returns: `true` if a reaction can be decoded; otherwise, `false`.
    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        guard let encodedStyle = data[Keys.style.rawValue] as? String,
              Reaction.Style(encodedValue: encodedStyle) != nil,
              data[Keys.userID.rawValue] is String else { return false }
        return true
    }
}
