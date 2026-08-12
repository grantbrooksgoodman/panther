//
//  ConversationID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A conversation's composite identifier.
///
/// A conversation identifier pairs a stable ``key`` that locates the conversation in the database
/// with a ``hash`` token that identifies the conversation's current content version.
struct ConversationID: Codable, Hashable {
    // MARK: - Properties

    /// The token that identifies the conversation's current content version.
    let hash: String

    /// The stable key that locates the conversation in the database.
    let key: String

    // MARK: - Init

    /// Creates a conversation identifier with the given key and hash.
    ///
    /// - Parameters:
    ///   - key: The stable key that locates the conversation in the database.
    ///   - hash: The token that identifies the conversation's current content version.
    init(
        key: String,
        hash: String
    ) {
        self.key = key
        self.hash = hash
    }

    /// Creates a conversation identifier from its string representation.
    ///
    /// Returns `nil` if the string does not contain exactly a key and hash separated by `" | "`.
    ///
    /// - Parameter string: The string representation of the conversation identifier.
    init?(_ string: String) {
        let components = string.components(separatedBy: " | ")
        guard components.count == 2 else { return nil }
        self = .init(
            key: components[0],
            hash: components[1]
        )
    }
}
