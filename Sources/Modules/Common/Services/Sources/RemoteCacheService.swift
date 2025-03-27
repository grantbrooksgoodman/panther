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

public struct RemoteCacheService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Remote Cache Status Configuration

    public func cacheStatus(userID: String) async -> Callback<RemoteCacheStatus, Exception> {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.invalidatedCaches.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.Networking.typecastFailed("array", metadata: [self, #file, #function, #line]))
            }

            return .success(array.contains(userID) ? .invalid : .valid)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    public func setCacheStatus(_ cacheStatus: RemoteCacheStatus, userID: String) async -> Exception? {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.invalidatedCaches.rawValue)

        switch getValuesResult {
        case let .success(values):
            var array = values as? [String] ?? []

            switch cacheStatus {
            case .invalid:
                array.append(userID)

            case .valid:
                array.removeAll(where: { $0 == userID })
            }

            array = array.unique
            return await networking.database.setValue(array, forKey: NetworkPath.invalidatedCaches.rawValue)

        case let .failure(exception):
            var exceptions = exception.isEqual(to: .Networking.Database.noValueExists) ? [] : [exception]
            if let exception = await networking.database.setValue([userID], forKey: NetworkPath.invalidatedCaches.rawValue) {
                exceptions.append(exception)
            }

            return exceptions.compiledException
        }
    }
}
