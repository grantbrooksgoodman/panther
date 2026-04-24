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

    typealias T = ReactionMetadata
    private typealias Keys = SerializationKeys

    // MARK: - Types

    private enum SerializationKeys: String {
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

    // MARK: - Methods

    static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.messageID.rawValue] is String,
              let encodedReactions = data[Keys.reactions.rawValue] as? [[String: Any]],
              encodedReactions.allSatisfy({ Reaction.canDecode(from: $0) }) else { return false }

        return true
    }

    static func decode(from data: [String: Any]) async -> Callback<ReactionMetadata, Exception> {
        guard let messageID = data[Keys.messageID.rawValue] as? String,
              let encodedReactions = data[Keys.reactions.rawValue] as? [[String: Any]] else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        var reactions = [Reaction]()
        let decodeResults = await encodedReactions.parallelMap(
            failForEmptyCollection: true
        ) {
            await Reaction.decode(from: $0)
        }

        switch decodeResults {
        case let .success(decodedReactions): reactions = decodedReactions
        case let .failure(exception): return .failure(exception)
        }

        let decoded: ReactionMetadata = .init(
            messageID: messageID,
            reactions: reactions
        )

        return .success(decoded)
    }
}
