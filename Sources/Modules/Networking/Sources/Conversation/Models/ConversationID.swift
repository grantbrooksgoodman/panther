//
//  ConversationID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct ConversationID: Codable, Hashable {
    // MARK: - Properties

    let hash: String
    let key: String

    // MARK: - Init

    init(key: String, hash: String) {
        self.key = key
        self.hash = hash
    }
}
