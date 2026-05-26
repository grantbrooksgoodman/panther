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

    // NIT: Can't I just call updateChildValues?
    func setCacheStatus(
        _ cacheStatus: RemoteCacheStatus,
        userID: String
    ) async throws(Exception) {
        var invalidatedCaches: [String]
        do {
            invalidatedCaches = try await networking.database.getValues(
                at: NetworkPath.invalidatedCaches.rawValue
            )
        } catch {
            var exceptions = error.isEqual(
                to: .Networking.Database.noValueExists
            ) ? [] : [error]

            do {
                try await networking.database.setValue(
                    [userID],
                    forKey: NetworkPath.invalidatedCaches.rawValue
                )
            } catch {
                exceptions.append(error)
            }

            if let exception = exceptions.compiledException {
                throw exception
            }

            return
        }

        switch cacheStatus {
        case .invalid: invalidatedCaches.append(userID)
        case .valid: invalidatedCaches.removeAll(where: { $0 == userID })
        }

        try await networking.database.setValue(
            invalidatedCaches.unique,
            forKey: NetworkPath.invalidatedCaches.rawValue
        )
    }
}
