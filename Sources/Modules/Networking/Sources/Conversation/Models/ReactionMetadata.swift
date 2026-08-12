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

/// The reactions applied to a single message.
struct ReactionMetadata: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    /// An empty reaction metadata placeholder.
    static let empty: ReactionMetadata = .init(
        messageID: .bangQualifiedEmpty,
        reactions: [
            .init(Reaction.Style.orderedCases.first ?? .love, userID: .bangQualifiedEmpty),
        ]
    )

    /// The identifier of the message the reactions apply to.
    let messageID: String

    /// The reactions applied to the message.
    let reactions: [Reaction]

    // MARK: - Computed Properties

    /// The strings that collectively define this instance's identity for hashing purposes, sorted
    /// alphabetically.
    var hashFactors: [String] {
        var factors = [messageID]
        factors.append(contentsOf: reactions.map(\.userID))
        factors.append(contentsOf: reactions.map(\.style.encodedValue))
        return factors.sorted()
    }
}
