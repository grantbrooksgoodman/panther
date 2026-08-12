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

/// A namespace for managing the in-memory queried contact pair cache.
@MainActor
enum QueriedContactPairCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case contactPairsForSearchTerms
    }

    // MARK: - Properties

    /// The contact pairs matching each search term.
    @Cached(CacheKey.contactPairsForSearchTerms) static var cachedContactPairsForSearchTerms: [String: [ContactPair]]?

    /// A Boolean value that indicates whether new values may be written to the cache.
    static var canWriteToCache = false

    // MARK: - Clear Cache

    /// Removes every cached contact pair.
    static func clearCache() {
        cachedContactPairsForSearchTerms = nil
    }
}
