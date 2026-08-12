//
//  ConversationID+Serializable.swift
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

extension ConversationID: Serializable {
    // MARK: - Properties

    /// The serialized representation of the conversation identifier.
    var encoded: String {
        "\(key) | \(hash)"
    }

    // MARK: - Init

    /// Creates a conversation identifier by decoding the given serialized string.
    ///
    /// - Parameter data: The serialized conversation identifier string.
    ///
    /// - Throws: An `Exception` if the string cannot be decoded.
    init(
        from data: String
    ) async throws(Exception) {
        let components = data.components(separatedBy: " | ")
        guard components.count == 2 else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self = .init(
            key: components[0],
            hash: components[1]
        )
    }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether a conversation identifier can be decoded
    /// from the given string.
    ///
    /// - Parameter data: The serialized conversation identifier string.
    ///
    /// - Returns: `true` if a conversation identifier can be decoded; otherwise, `false`.
    static func canDecode(
        from data: String
    ) -> Bool {
        data.components(separatedBy: " | ").count == 2
    }
}
