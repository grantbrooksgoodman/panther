//
//  Storage.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct Storage {
    // MARK: - Dependencies

    @Dependency(\.coreStorage) private var coreStorage: CoreStorage

    // MARK: - Global Cache Strategy

    /// Overrides the `CacheStrategy` for all `Storage` methods. Pass `nil` to revert the override.
    public func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        coreStorage.setGlobalCacheStrategy(globalCacheStrategy)
    }

    // MARK: - Data Upload

    public func upload(
        _ data: Data,
        metadata: Metadata,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreStorage.upload(
                data,
                metadata: metadata,
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    // MARK: - Deletion

    public func deleteItem(
        at path: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreStorage.deleteItem(
                at: path,
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    // MARK: - Download

    public func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreStorage.downloadItem(
                at: path,
                to: localPath,
                prependingEnvironment: prependingEnvironment,
                cacheStrategy: cacheStrategy,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    // MARK: - Item Exists

    public func itemExists(
        at path: String,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Callback<Bool, Exception> {
        return await withCheckedContinuation { continuation in
            coreStorage.itemExists(
                at: path,
                prependingEnvironment: prependingEnvironment,
                cacheStrategy: cacheStrategy,
                timeout: duration
            ) { itemExistsResult in
                continuation.resume(returning: itemExistsResult)
            }
        }
    }

    // MARK: - Clear Cache

    public func clearCache() {
        coreStorage.clearCache()
    }
}

/* MARK: CoreStorage Dependency */

private enum CoreStorageDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> CoreStorage {
        .init()
    }
}

private extension DependencyValues {
    var coreStorage: CoreStorage {
        get { self[CoreStorageDependency.self] }
        set { self[CoreStorageDependency.self] = newValue }
    }
}
