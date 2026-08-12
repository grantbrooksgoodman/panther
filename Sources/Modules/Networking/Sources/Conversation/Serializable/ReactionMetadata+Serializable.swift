//
//  ReactionMetadata+Serializable.swift
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

extension ReactionMetadata: Serializable {
    // MARK: - Type Aliases

    private typealias Keys = SerializableKey

    // MARK: - Types

    /// The serializable keys for encoding and decoding reaction metadata.
    enum SerializableKey: String {
        case messageID
        case reactions
    }

    // MARK: - Properties

    /// The serialized representation of the reaction metadata.
    var encoded: [String: Any] {
        [
            Keys.messageID.rawValue: messageID,
            Keys.reactions.rawValue: reactions.map(\.encoded),
        ]
    }

    // MARK: - Init

    /// Creates reaction metadata by decoding the given serialized data.
    ///
    /// - Parameter data: The serialized reaction metadata.
    ///
    /// - Throws: An `Exception` if the data cannot be decoded.
    init(
        from data: [String: Any]
    ) async throws(Exception) {
        guard let messageID = data[Keys.messageID.rawValue] as? String,
              let encodedReactions = data[Keys.reactions.rawValue] as? [[String: Any]] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let reactions = try await encodedReactions.parallelMap(
            failForEmptyCollection: true
        ) {
            try await Reaction(from: $0)
        }

        self = .init(
            messageID: messageID,
            reactions: reactions
        )
    }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether reaction metadata can be decoded from the
    /// given data.
    ///
    /// - Parameter data: The serialized reaction metadata.
    ///
    /// - Returns: `true` if reaction metadata can be decoded; otherwise, `false`.
    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        guard data[Keys.messageID.rawValue] is String,
              let encodedReactions = data[Keys.reactions.rawValue] as? [[String: Any]],
              encodedReactions.allSatisfy({
                  Reaction.canDecode(from: $0)
              }) else { return false }
        return true
    }
}
