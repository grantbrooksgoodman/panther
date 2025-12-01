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

enum QueriedContactPairCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case contactPairsForSearchTerms
    }

    // MARK: - Properties

    @Cached(CacheKey.contactPairsForSearchTerms) static var cachedContactPairsForSearchTerms: [String: [ContactPair]]?
    static var canWriteToCache = false

    // MARK: - Clear Cache

    static func clearCache() {
        cachedContactPairsForSearchTerms = nil
    }
}
