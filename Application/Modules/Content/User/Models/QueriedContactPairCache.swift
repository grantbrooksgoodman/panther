//
//  QueriedContactPairCache.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum QueriedContactPairCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case contactPairsForSearchTerms
    }

    // MARK: - Properties

    @Cached(CacheKey.contactPairsForSearchTerms) public static var cachedContactPairsForSearchTerms: [String: [ContactPair]]?

    // MARK: - Clear Cache

    public static func clearCache() {
        cachedContactPairsForSearchTerms = nil
    }
}
