//
//  ReactionSessionServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A unique identifier for an effect registered with `ReactionSessionService`.
struct ReactionSessionServiceEffectID: Hashable {
    // MARK: - Properties

    /// The string that identifies the effect.
    let rawValue: String

    // MARK: - Init

    /// Creates an identifier with the given string.
    ///
    /// - Parameter rawValue: The string that identifies the effect.
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ReactionSessionServiceEffectID {
    static let reloadCollectionView: ReactionSessionServiceEffectID = .init("reloadCollectionView")
    static let scrollToLastItem: ReactionSessionServiceEffectID = .init("scrollToLastItem")
}
