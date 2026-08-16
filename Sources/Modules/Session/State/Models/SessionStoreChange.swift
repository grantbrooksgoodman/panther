//
//  SessionStoreChange.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A change to the contents of the session store.
enum SessionStoreChange: Equatable {
    // MARK: - Types

    /// The category of contents a change affects.
    enum Kind: CaseIterable {
        /// The conversations in the store.
        case conversations

        /// The messages in the store.
        case messages

        /// The users in the store.
        case users
    }

    // MARK: - Cases

    /// A change to the store's conversations, carrying the upserted and removed conversation
    /// identifier keys.
    case conversations(upsertedIDKeys: Set<String>, removedIDKeys: Set<String>)

    /// A change to the store's messages, carrying the upserted and removed message identifiers.
    case messages(upsertedIDs: Set<String>, removedIDs: Set<String>)

    /// A change to the store's users, carrying the upserted and removed user identifiers.
    case users(upsertedIDs: Set<String>, removedIDs: Set<String>)

    // MARK: - Properties

    /// The category of contents the change affects.
    var kind: Kind {
        switch self {
        case .conversations: .conversations
        case .messages: .messages
        case .users: .users
        }
    }
}
