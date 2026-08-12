//
//  RemoteCacheService.swift
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

/// Use ``RemoteCacheService`` to read and write the remote cache status of individual users.
///
/// The remote cache status is stored per user in the remote database, as a hosted list of the
/// user IDs whose caches have been invalidated.
struct RemoteCacheService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Remote Cache Status Configuration

    /// Returns the remote cache status for the given user.
    ///
    /// - Parameter userID: The ID of the user whose status to fetch.
    ///
    /// - Returns: ``RemoteCacheStatus/invalid`` if the user appears in the hosted invalidated
    ///   caches list; otherwise, ``RemoteCacheStatus/valid``.
    ///
    /// - Throws: An `Exception` if fetching the list fails.
    func cacheStatus(userID: String) async throws(Exception) -> RemoteCacheStatus {
        let invalidatedCaches: [String] = try await networking.database.getValues(
            at: NetworkPath.invalidatedCaches.rawValue,
            cacheStrategy: .adaptive
        )

        return invalidatedCaches.contains(userID) ? .invalid : .valid
    }

    /// Sets the remote cache status for the given user.
    ///
    /// The hosted invalidated caches list is modified atomically: setting
    /// ``RemoteCacheStatus/invalid`` adds the user to the list, and setting
    /// ``RemoteCacheStatus/valid`` removes them.
    ///
    /// - Parameters:
    ///   - cacheStatus: The status to set.
    ///   - userID: The ID of the user whose status to set.
    ///
    /// - Throws: An `Exception` if the update fails.
    func setCacheStatus(
        _ cacheStatus: RemoteCacheStatus,
        userID: String
    ) async throws(Exception) {
        try await networking.database.runTransaction(
            at: NetworkPath.invalidatedCaches.rawValue
        ) { currentValue in
            var ids = (currentValue as? [String]) ?? []
            switch cacheStatus {
            case .invalid: ids.append(userID)
            case .valid: ids.removeAll(where: { $0 == userID })
            }

            return ids.unique
        }
    }
}
