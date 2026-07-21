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
        @Dependency(\.networking.database) var database: DatabaseDelegate
        @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter

        switch key {
        case .blockedUserIDs:
            guard let updates = merge(
                updates: updated.blockedUserIDs,
                with: blockedUserIDs,
                at: [
                    NetworkPath.users.rawValue,
                    id,
                    SerializableKey.blockedUserIDs.rawValue,
                ].joined(separator: "/")
            ) else { return .handled(updated) }

            try await database.commit(updates)
            return .handled(updated)

        case .pushTokens:
            guard let updates = merge(
                updates: updated.pushTokens,
                with: pushTokens,
                at: [
                    NetworkPath.users.rawValue,
                    id,
                    SerializableKey.pushTokens.rawValue,
                ].joined(separator: "/")
            ) else { return .handled(updated) }

            try await database.commit(updates)
            return .handled(updated)

        default:
            guard let date = value as? Date else { return .proceed }
            return .encoded(timestampDateFormatter.string(from: date))
        }
    }

    // MARK: - Auxiliary

    private func merge(
        updates newData: [String]?,
        with currentData: [String]?,
        at path: String
    ) -> [String: Any]? {
        let currentData = Set(currentData ?? [])
        let newData = Set(newData ?? [])
        guard currentData != newData else { return nil }

        var updates = [String: Any]()
        for added in newData.subtracting(currentData) {
            updates["\(path)/\(added)"] = true
        }

        for removed in currentData.subtracting(newData) {
            updates["\(path)/\(removed)"] = NSNull()
        }

        guard !updates.isEmpty else { return nil }
        return updates
    }
}
