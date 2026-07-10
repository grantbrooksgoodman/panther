//
//  UserCache.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

@MainActor
enum UserCache {
    // MARK: - Properties

    static var knownUsers: [User] {
        if let cachedValue = _UserCache.cachedUsers {
            return cachedValue
        }

        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        @Persistent(.unknownContactPairArchive) var unknownContactPairArchive: [ContactPair]?

        let usersFromContactPairArchive = contactPairArchive?
            .flatMap(\.users) ?? []

        let usersFromSessionStore = sessionStore
            .users
            .values

        let usersFromUnknownContactPairArchive = unknownContactPairArchive?
            .flatMap(\.users) ?? []

        let uniqueUsers = (
            usersFromSessionStore +
                usersFromContactPairArchive +
                usersFromUnknownContactPairArchive
        ).uniquedByID

        _UserCache.cachedUsers = uniqueUsers
        return uniqueUsers
    }

    // MARK: - Methods

    static func clearCache() {
        _UserCache.clearCache()
    }
}

@MainActor
private enum _UserCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case users
    }

    // MARK: - Properties

    @Cached(CacheKey.users) fileprivate static var cachedUsers: [User]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedUsers = nil
    }
}
