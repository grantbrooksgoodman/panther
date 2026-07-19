//
//  User+RemotelyUpdatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension User: RemotelyUpdatable {
    // MARK: - Properties

    var identifier: String {
        id
    }

    // MARK: - Did Write

    func didWrite(
        _ updated: User,
        forKey key: SerializableKey
    ) async throws(Exception) -> User {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        // Single source of upsert for single-field update calls.
        sessionStore.upsertUser(updated)
        return updated
    }

    // MARK: - Will Write

    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: User
    ) async throws(Exception) -> WriteAction<User> {
        switch key {
        case .blockedUserIDs:
            let newIDs = Set(updated.blockedUserIDs ?? [])
            let oldIDs = Set(blockedUserIDs ?? [])

            guard newIDs != oldIDs else { return .handled(updated) }

            let basePath = [
                NetworkPath.users.rawValue,
                id,
                SerializableKey.blockedUserIDs.rawValue,
            ].joined(separator: "/")

            var updates = [String: Any]()
            for added in newIDs.subtracting(oldIDs) {
                updates["\(basePath)/\(added)"] = true
            }

            for removed in oldIDs.subtracting(newIDs) {
                updates["\(basePath)/\(removed)"] = NSNull()
            }

            guard !updates.isEmpty else { return .handled(updated) }

            @Dependency(\.networking.database) var database: DatabaseDelegate
            try await database.commit(updates)
            return .handled(updated)

        default:
            @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter
            guard let date = value as? Date else { return .proceed }
            return .encoded(timestampDateFormatter.string(from: date))
        }
    }
}
