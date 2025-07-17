//
//  QueriedConversationCache.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum QueriedConversationCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case conversationsForSearchTerms
    }

    // MARK: - Properties

    @Cached(CacheKey.conversationsForSearchTerms) public static var cachedConversationsForSearchTerms: [String: [Conversation]]?

    // MARK: - Clear Cache

    public static func clearCache() {
        cachedConversationsForSearchTerms = nil
    }
}
