//
//  Database.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct Database {
    // MARK: - Dependencies

    @Dependency(\.coreDatabase) private var coreDatabase: CoreDatabase

    // MARK: - Data Integrity Validation

    public func isEncodable(_ value: Any) -> Bool {
        coreDatabase.isEncodable(value)
    }

    // MARK: - ID Key Generation

    public func generateKey(for path: String) -> String? {
        coreDatabase.generateKey(for: path)
    }

    // MARK: - Global Cache Strategy

    /// Overrides the `CacheStrategy` for all `Database` methods. Pass `nil` to revert the override.
    public func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        coreDatabase.setGlobalCacheStrategy(globalCacheStrategy)
    }

    // MARK: - Value Retrieval

    /**
     Gets the hosted values at the given path.

     - Parameter path: The hosting path at which to retrieve values.
     - Parameter prependingEnvironment: Pass `true` to prepend the current network environment to the given `path`.
     - Parameter cacheStrategy: The caching strategy to use; defaults to `.returnCacheFirst`.
     - Parameter timeout: An optional timeout `Duration` for the operation; defaults to `.seconds(10)`.

     - Returns: A `Callback` type composed of the data value at the given path or an `Exception`.
     */
    public func getValues(
        at path: String,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Callback<Any, Exception> {
        return await withCheckedContinuation { continuation in
            coreDatabase.getValues(
                at: path,
                prependingEnvironment: prependingEnvironment,
                cacheStrategy: cacheStrategy,
                timeout: duration
            ) { getValuesResult in
                continuation.resume(returning: getValuesResult)
            }
        }
    }

    public func queryValues(
        at path: String,
        strategy: CoreDatabase.QueryStrategy = .first(10),
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Callback<Any, Exception> {
        return await withCheckedContinuation { continuation in
            coreDatabase.queryValues(
                at: path,
                strategy: strategy,
                prependingEnvironment: prependingEnvironment,
                cacheStrategy: cacheStrategy,
                timeout: duration
            ) { queryValuesResult in
                continuation.resume(returning: queryValuesResult)
            }
        }
    }

    // MARK: - Value Setting

    @discardableResult
    public func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreDatabase.setValue(
                value,
                forKey: key,
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    @discardableResult
    public func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreDatabase.updateChildValues(
                forKey: key,
                with: data,
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    // MARK: - Populate Cache

    /// Temporarily populates the cache with a long-lasting snapshot of the database at the current moment.
    public func populateTemporaryCaches() async -> Exception? {
        await coreDatabase.populateTemporaryCaches()
    }

    // MARK: - Clear Cache

    public func clearCache() {
        coreDatabase.clearCache()
    }

    // MARK: - Clear Temporary Caches

    /// Clears select long-lasting caches.
    public func clearTemporaryCaches() {
        coreDatabase.clearTemporaryCaches()
    }
}

/* MARK: CoreDatabase Dependency */

private enum CoreDatabaseDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> CoreDatabase {
        .init()
    }
}

private extension DependencyValues {
    var coreDatabase: CoreDatabase {
        get { self[CoreDatabaseDependency.self] }
        set { self[CoreDatabaseDependency.self] = newValue }
    }
}
