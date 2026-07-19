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

struct RemoteCacheService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Remote Cache Status Configuration

    func cacheStatus(userID: String) async throws(Exception) -> RemoteCacheStatus {
        let invalidatedCaches: [String] = try await networking.database.getValues(
            at: NetworkPath.invalidatedCaches.rawValue
        )

        return invalidatedCaches.contains(userID) ? .invalid : .valid
    }

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
