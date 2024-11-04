//
//  ReactionSessionServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ReactionSessionServiceEffectID: Hashable {
    // MARK: - Properties

    public let rawValue: String

    // MARK: - Init

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
