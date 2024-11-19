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

    public typealias T = ReactionMetadata
    private typealias Keys = SerializationKeys

    // MARK: - Types

    private enum SerializationKeys: String {
        case messageID
        case reactions
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        [
            Keys.messageID.rawValue: messageID,
            Keys.reactions.rawValue: reactions.map(\.encoded),
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.messageID.rawValue] as? String != nil,
              let encodedReactions = data[Keys.reactions.rawValue] as? [[String: Any]],
              encodedReactions.allSatisfy({ Reaction.canDecode(from: $0) }) else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<ReactionMetadata, Exception> {
        guard let messageID = data[Keys.messageID.rawValue] as? String,
              let encodedReactions = data[Keys.reactions.rawValue] as? [[String: Any]] else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        var reactions = [Reaction]()

        for encodedReaction in encodedReactions {
            let decodeResult = await Reaction.decode(from: encodedReaction)

            switch decodeResult {
            case let .success(reaction):
                reactions.append(reaction)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard !reactions.isEmpty,
              reactions.count == encodedReactions.count else {
            return .failure(.init("Mismatched ratio returned.", metadata: [self, #file, #function, #line]))
        }

        let decoded: ReactionMetadata = .init(messageID: messageID, reactions: reactions)
        return .success(decoded)
    }
}
