//
//  CoreStorage.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable type_body_length

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import FirebaseStorage

public final class CoreStorage {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case downloadItemResults
        case itemExistsResults
    }

    // MARK: - Dependencies

    @Dependency(\.currentCalendar) private var calendar: Calendar
    @Dependency(\.networking.delegates) private var delegates: NetworkDelegates
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.firebaseStorage) private var firebaseStorage: StorageReference

    // MARK: - Properties

    // CacheStrategy
    private var globalCacheStrategy: CacheStrategy?

    // Dictionary
    @Cached(CacheKey.downloadItemResults) private var cachedDownloadItemResults: [String: DataSample]?
    @Cached(CacheKey.itemExistsResults) private var cachedItemExistsResults: [String: DataSample]?

    // MARK: - Global Cache Strategy

    public func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        self.globalCacheStrategy = globalCacheStrategy
    }

    // MARK: - Data Upload

    public func upload(
        _ data: Data,
        metadata: Storage.Metadata,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        guard delegates.connectionStatusProvider.isOnline else {
            completion(.internetConnectionOffline([self, #file, #function, #line]))
            return
        }

        delegates.activityIndicator.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            delegates.activityIndicator.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Uploading data to path \"\(metadata.filePath)\".",
            domain: .storage,
            metadata: [self, #file, #function, #line]
        )

        cachedDownloadItemResults?[metadata.filePath] = nil
        cachedItemExistsResults?[metadata.filePath] = nil

        firebaseStorage.putData(
            data,
            metadata: metadata.asStorageMetadata(prependingEnvironment: prependingEnvironment)
        ) { putDataResult in
            timeout.cancel()
            guard canComplete else { return }

            switch putDataResult {
            case .success:
                completion(nil)

            case let .failure(error):
                completion(.init(error, metadata: [self, #file, #function, #line]))
            }
        }
    }

    // MARK: - Deletion

    public func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        guard delegates.connectionStatusProvider.isOnline else {
            completion(.internetConnectionOffline([self, #file, #function, #line]))
            return
        }

        delegates.activityIndicator.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            delegates.activityIndicator.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Deleting item at path \"\(path)\".",
            domain: .storage,
            metadata: [self, #file, #function, #line]
        )

        cachedDownloadItemResults?[path] = nil
        cachedItemExistsResults?[path] = nil

        let itemPath = prependingEnvironment ? path.prependingCurrentEnvironment : path
        let itemReference = firebaseStorage.child(itemPath)
        itemReference.delete { error in
            timeout.cancel()
            guard canComplete else { return }

            if let error {
                completion(.init(error, metadata: [self, #file, #function, #line]))
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Download

    // swiftlint:disable:next function_parameter_count
    public func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        let cacheStrategy = globalCacheStrategy ?? cacheStrategy
        guard delegates.connectionStatusProvider.isOnline else {
            completion(.internetConnectionOffline([self, #file, #function, #line]))
            return
        }

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            delegates.activityIndicator.hide()
            return true
        }

        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path
        func completeWithCacheIfPresent() -> Bool {
            guard cachedDownloadItemResultIsValid(localPath: localPath, networkPath: path),
                  canComplete else { return false }
            completion(nil)
            return true
        }

        if cacheStrategy == .returnCacheFirst,
           completeWithCacheIfPresent() {
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Downloading item at path \"\(path)\".",
            domain: .storage,
            metadata: [self, #file, #function, #line]
        )

        let itemReference = firebaseStorage.child(path)
        let writeStartDate = Date.now
        delegates.activityIndicator.show()

        itemReference.write(toFile: localPath) { writeResult in
            timeout.cancel()
            let cacheExpiry = Networking.cacheExpiryMilliseconds(for: writeStartDate)

            switch writeResult {
            case .success:
                var cachedDownloadItemResults = self.cachedDownloadItemResults ?? [:]
                cachedDownloadItemResults[path] = .init(
                    .now,
                    data: localPath,
                    expiresAfter: .milliseconds(cacheExpiry)
                )
                self.cachedDownloadItemResults = cachedDownloadItemResults

                guard canComplete else { return }
                completion(nil)

            case let .failure(error):
                if cacheStrategy == .returnCacheOnFailure,
                   completeWithCacheIfPresent() {}

                guard canComplete else { return }
                completion(.init(error, metadata: [self, #file, #function, #line]))
            }
        }
    }

    // MARK: - Item Exists

    public func itemExists(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration,
        completion: @escaping (_ callback: Callback<Bool, Exception>) -> Void
    ) {
        let cacheStrategy = globalCacheStrategy ?? cacheStrategy
        guard delegates.connectionStatusProvider.isOnline else {
            completion(.failure(.internetConnectionOffline([self, #file, #function, #line])))
            return
        }

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            delegates.activityIndicator.hide()
            return true
        }

        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path
        func completeWithCacheIfPresent() -> Bool {
            guard let cachedItemExistsResult = cachedItemExistsResult(path: path),
                  canComplete else { return false }
            completion(.success(cachedItemExistsResult))
            return true
        }

        if cacheStrategy == .returnCacheFirst,
           completeWithCacheIfPresent() {
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.failure(.timedOut([self, #file, #function, #line])))
        }

        Logger.log(
            "Checking item exists at path \"\(path)\".",
            domain: .storage,
            metadata: [self, #file, #function, #line]
        )

        let itemReference = firebaseStorage.child(path)
        let getMetadataStartDate = Date.now
        delegates.activityIndicator.show()

        itemReference.getMetadata { getMetadataResult in
            timeout.cancel()
            let cacheExpiry = Networking.cacheExpiryMilliseconds(for: getMetadataStartDate)

            switch getMetadataResult {
            case .success:
                var cachedItemExistsResults = self.cachedItemExistsResults ?? [:]
                cachedItemExistsResults[path] = .init(
                    .now,
                    data: true,
                    expiresAfter: .milliseconds(cacheExpiry)
                )
                self.cachedItemExistsResults = cachedItemExistsResults

                guard canComplete else { return }
                completion(.success(true))

            case let .failure(error):
                let exception: Exception = .init(error, metadata: [self, #file, #function, #line])
                if !exception.isEqual(to: .genericStorageError) {
                    Logger.log(exception)
                }

                if cacheStrategy == .returnCacheOnFailure,
                   completeWithCacheIfPresent() {
                    return
                }

                var cachedItemExistsResults = self.cachedItemExistsResults ?? [:]
                cachedItemExistsResults[path] = .init(
                    .now,
                    data: false,
                    expiresAfter: .milliseconds(cacheExpiry)
                )
                self.cachedItemExistsResults = cachedItemExistsResults

                guard canComplete else { return }
                completion(.success(false))
            }
        }
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cachedDownloadItemResults = nil
        cachedItemExistsResults = nil
    }

    // MARK: - Auxiliary

    private func cachedDownloadItemResultIsValid(localPath: URL, networkPath: String) -> Bool {
        guard let cachedDataSample = cachedDownloadItemResults?[networkPath] else { return false }

        guard !cachedDataSample.isExpired,
              let cachedLocalPath = cachedDataSample.data as? URL,
              cachedLocalPath == localPath,
              fileManager.fileExists(atPath: localPath.path()) || fileManager.fileExists(atPath: localPath.path(percentEncoded: false)) else {
            cachedDownloadItemResults?[networkPath] = nil
            return false
        }

        Logger.log(
            "Returning cached download item result for network path \"\(networkPath)\".",
            domain: .caches,
            metadata: [self, #file, #function, #line]
        )

        return true
    }

    private func cachedItemExistsResult(path: String) -> Bool? {
        guard let cachedDataSample = cachedItemExistsResults?[path] else { return nil }

        guard !cachedDataSample.isExpired,
              let cachedItemExistsResult = cachedDataSample.data as? Bool else {
            cachedItemExistsResults?[path] = nil
            return nil
        }

        Logger.log(
            "Returning cached item exists result for network path \"\(path)\".",
            domain: .caches,
            metadata: [self, #file, #function, #line]
        )

        return cachedItemExistsResult
    }
}

// swiftlint:enable type_body_length
