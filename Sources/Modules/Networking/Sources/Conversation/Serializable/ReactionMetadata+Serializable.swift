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

    private enum SerializableKey: String {
        case messageID
        case reactions
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        [
            Keys.messageID.rawValue: messageID,
            Keys.reactions.rawValue: reactions.map(\.encoded),
        ]
    }

    // MARK: - Init

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
