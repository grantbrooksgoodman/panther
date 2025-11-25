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

public enum UserCache {
    // MARK: - Properties

    // TODO: Clear on updatedCurrentUser & syncContactPairArchive.
    static var knownUsers: [User] {
        if let cachedValue = _UserCache.users {
            return cachedValue
        }

        @Dependency(\.clientSession) var clientSession: ClientSession

        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
        @Persistent(.unknownContactPairArchive) var unknownContactPairArchive: [ContactPair]?

        let usersFromContactPairArchive = contactPairArchive?
            .map(\.users)
            .reduce([], +) ?? []

        let usersFromConversationArchive = conversationArchive?
            .compactMap(\.users)
            .reduce([], +) ?? []

        let usersFromCurrentConversation = clientSession
            .conversation
            .fullConversation?
            .users ?? clientSession
            .conversation
            .currentConversation?
            .users ?? []

        let usersFromCurrentUserConversations = clientSession
            .user
            .currentUser?
            .conversations?
            .compactMap(\.users)
            .reduce([], +) ?? []

        let usersFromUnknownContactPairArchive = unknownContactPairArchive?
            .map(\.users)
            .reduce([], +) ?? []

        let uniqueUsers = (usersFromContactPairArchive +
            usersFromConversationArchive +
            usersFromCurrentConversation +
            usersFromCurrentUserConversations +
            usersFromUnknownContactPairArchive).unique

        _UserCache.users = uniqueUsers
        return uniqueUsers
    }

    // MARK: - Methods

    public static func clearCache() {
        _UserCache.clearCache()
    }
}

private enum _UserCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case users
    }

    // MARK: - Properties

    @Cached(CacheKey.users) fileprivate static var users: [User]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        users = nil
    }
}
