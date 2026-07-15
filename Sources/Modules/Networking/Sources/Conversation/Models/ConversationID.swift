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

    init(
        key: String,
        hash: String
    ) {
        self.key = key
        self.hash = hash
    }

    init?(_ string: String) {
        let components = string.components(separatedBy: " | ")
        guard components.count == 2 else { return nil }
        self = .init(
            key: components[0],
            hash: components[1]
        )
    }
}
