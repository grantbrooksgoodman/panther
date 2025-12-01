//
//  ReactionSessionServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct ReactionSessionServiceEffectID: Hashable {
    // MARK: - Properties

    let rawValue: String

    // MARK: - Init

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ReactionSessionServiceEffectID {
    static let reloadCollectionView: ReactionSessionServiceEffectID = .init("reloadCollectionView")
    static let scrollToLastItem: ReactionSessionServiceEffectID = .init("scrollToLastItem")
}
