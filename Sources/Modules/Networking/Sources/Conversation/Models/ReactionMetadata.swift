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

struct ReactionMetadata: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    static let empty: ReactionMetadata = .init(
        messageID: .bangQualifiedEmpty,
        reactions: [
            .init(Reaction.Style.orderedCases.first ?? .love, userID: .bangQualifiedEmpty),
        ]
    )

    let messageID: String
    let reactions: [Reaction]

    // MARK: - Computed Properties

    var hashFactors: [String] {
        var factors = [messageID]
        factors.append(contentsOf: reactions.map(\.userID))
        factors.append(contentsOf: reactions.map(\.style.encodedValue))
        return factors.sorted()
    }

    // MARK: - Init

    init(
        messageID: String,
        reactions: [Reaction]
    ) {
        self.messageID = messageID
        self.reactions = reactions
    }
}
