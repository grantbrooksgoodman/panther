//
//  SessionStoreChange.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum SessionStoreChange: Equatable {
    // MARK: - Types

    enum Kind: CaseIterable {
        case conversations
        case messages
        case users
    }

    // MARK: - Cases

    case conversations(upsertedIDKeys: Set<String>, removedIDKeys: Set<String>)
    case messages(upsertedIDs: Set<String>, removedIDs: Set<String>)
    case users(upsertedIDs: Set<String>, removedIDs: Set<String>)

    // MARK: - Properties

    var kind: Kind {
        switch self {
        case .conversations: .conversations
        case .messages: .messages
        case .users: .users
        }
    }
}
