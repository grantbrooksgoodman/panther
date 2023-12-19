//
//  CoreStorage.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseStorage
import Redux

public struct CoreStorage {
    // MARK: - Dependencies

    @Dependency(\.firebaseStorage) private var firebaseStorage: StorageReference
    @Dependency(\.networking.activityIndicator) private var networkActivity: NetworkActivityIndicator

    // MARK: - Data Upload

    public func upload(
        _ data: Data,
        metadata: Storage.Metadata,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

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
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

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

    public func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        let itemPath = prependingEnvironment ? path.prependingCurrentEnvironment : path
        let itemReference = firebaseStorage.child(itemPath)

        itemReference.write(toFile: localPath) { writeResult in
            timeout.cancel()
            guard canComplete else { return }

            switch writeResult {
            case .success:
                completion(nil)

            case let .failure(error):
                completion(.init(error, metadata: [self, #file, #function, #line]))
            }
        }
    }

    // MARK: - Item Exists

    public func itemExists(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ callback: Callback<Bool, Exception>) -> Void
    ) {
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.failure(.timedOut([self, #file, #function, #line])))
        }

        let itemPath = prependingEnvironment ? path.prependingCurrentEnvironment : path
        let itemReference = firebaseStorage.child(itemPath)

        itemReference.getMetadata { getMetadataResult in
            timeout.cancel()
            guard canComplete else { return }

            switch getMetadataResult {
            case .success:
                completion(.success(true))

            case let .failure(error):
                let exception: Exception = .init(error, metadata: [self, #file, #function, #line])
                if !exception.isEqual(to: .genericStorageError) {
                    Logger.log(exception)
                }
                completion(.success(false))
            }
        }
    }
}
