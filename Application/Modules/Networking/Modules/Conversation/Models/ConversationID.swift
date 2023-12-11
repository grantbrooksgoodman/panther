//
//  ConversationID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ConversationID: Codable, Equatable {
    // MARK: - Properties

    public let hash: String
    public let key: String

    // MARK: - Init

    public init(key: String, hash: String) {
        self.key = key
        self.hash = hash
    }

    public init?(_ string: String) {
        let components = string.components(separatedBy: " | ")
        guard components.count > 1 else { return nil }
        self.init(key: components[0], hash: components[1])
    }
}
