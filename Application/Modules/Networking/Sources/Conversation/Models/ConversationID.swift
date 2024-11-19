//
//  ConversationID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ConversationID: Codable, Hashable {
    // MARK: - Properties

    public let hash: String
    public let key: String

    // MARK: - Init

    public init(key: String, hash: String) {
        self.key = key
        self.hash = hash
    }
}
