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

    func cacheStatus(userID: String) async -> Callback<RemoteCacheStatus, Exception> {
        do {
            let invalidatedCaches: [String] = try await networking.database.getValues(
                at: NetworkPath.invalidatedCaches.rawValue
            )
            return .success(invalidatedCaches.contains(userID) ? .invalid : .valid)
        } catch {
            return .failure(error)
        }
    }

    // NIT: Can't I just call updateChildValues?
    func setCacheStatus(
        _ cacheStatus: RemoteCacheStatus,
        userID: String
    ) async -> Exception? {
        var invalidatedCaches: [String]
        do {
            invalidatedCaches = try await networking.database.getValues(
                at: NetworkPath.invalidatedCaches.rawValue
            )
        } catch {
            var exceptions = error.isEqual(to: .Networking.Database.noValueExists) ? [] : [error]
            if let exception = await networking.database.setValue(
                [userID],
                forKey: NetworkPath.invalidatedCaches.rawValue
            ) {
                exceptions.append(exception)
            }

            return exceptions.compiledException
        }

        switch cacheStatus {
        case .invalid: invalidatedCaches.append(userID)
        case .valid: invalidatedCaches.removeAll(where: { $0 == userID })
        }

        invalidatedCaches = invalidatedCaches.unique
        return await networking.database.setValue(
            invalidatedCaches,
            forKey: NetworkPath.invalidatedCaches.rawValue
        )
    }
}
