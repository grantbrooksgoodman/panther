//
//  ReactionMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct ReactionMetadata: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    public let messageID: String
    public let reactions: [Reaction]

    // MARK: - Computed Properties

    public var hashFactors: [String] {
        var factors = [messageID]
        factors.append(contentsOf: reactions.map(\.userID))
        factors.append(contentsOf: reactions.map(\.style.encodedValue))
        return factors
    }

    // MARK: - Computed Properties

    public static let empty: ReactionMetadata = .init(
        messageID: .bangQualifiedEmpty,
        reactions: [
            .init(.like, userID: .bangQualifiedEmpty),
        ]
    )

    // MARK: - Init

    public init(
        messageID: String,
        reactions: [Reaction]
    ) {
        self.messageID = messageID
        self.reactions = reactions
    }
}
