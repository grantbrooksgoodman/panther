//
//  MetadataService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public final class MetadataService {
    // MARK: - Types

    private enum MetadataServiceKey: String {
        /* MARK: Cases */

        case appShareLink
        case appStoreBuildNumber
        case redirectionKey
        case shouldForceUpdate
        case storageReferenceURL

        /* MARK: Properties */

        public var path: String {
            @Dependency(\.networking.config.paths.shared) var sharedPath: String
            return "\(sharedPath)/\(rawValue)"
        }
    }

    // MARK: - Dependencies

    @Dependency(\.networking.database) private var database: Database

    // MARK: - Properties

    public private(set) var appShareLink: URL?
    public private(set) var appStoreBuildNumber: Int?
    public private(set) var redirectionKey: String?
    public private(set) var shouldForceUpdate: Bool?
    public private(set) var storageReferenceURL: URL?

    // MARK: - Resolve All Values

    public func resolveValues() async -> Exception? {
        if appShareLink == nil {
            let getAppShareLinkResult = await getAppShareLink()

            switch getAppShareLinkResult {
            case let .success(appShareLink):
                self.appShareLink = appShareLink

            case let .failure(exception):
                return exception
            }
        }

        if appStoreBuildNumber == nil {
            let getAppStoreBuildNumberResult = await getAppStoreBuildNumber()

            switch getAppStoreBuildNumberResult {
            case let .success(appStoreBuildNumber):
                self.appStoreBuildNumber = appStoreBuildNumber

            case let .failure(exception):
                return exception
            }
        }

        if redirectionKey == nil {
            let getRedirectionKeyResult = await getRedirectionKey()

            switch getRedirectionKeyResult {
            case let .success(redirectionKey):
                self.redirectionKey = redirectionKey

            case let .failure(exception):
                return exception
            }
        }

        if shouldForceUpdate == nil {
            let getShouldForceUpdateResult = await getShouldForceUpdate()

            switch getShouldForceUpdateResult {
            case let .success(shouldForceUpdate):
                self.shouldForceUpdate = shouldForceUpdate

            case let .failure(exception):
                return exception
            }
        }

        if storageReferenceURL == nil {
            let getStorageReferenceURLResult = await getStorageReferenceURL()

            switch getStorageReferenceURLResult {
            case let .success(storageReferenceURL):
                self.storageReferenceURL = storageReferenceURL

            case let .failure(exception):
                return exception
            }
        }

        return nil
    }

    // MARK: - Individual Value Retrieval

    private func getAppShareLink() async -> Callback<URL, Exception> {
        let getValuesResult = await database.getValues(
            at: MetadataServiceKey.appShareLink.path,
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let urlString = values as? String,
                  let appShareLink = URL(string: urlString) else {
                return .failure(.typecastFailed("URL", metadata: [self, #file, #function, #line]))
            }

            return .success(appShareLink)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getAppStoreBuildNumber() async -> Callback<Int, Exception> {
        let getValuesResult = await database.getValues(
            at: MetadataServiceKey.appStoreBuildNumber.path,
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let appStoreBuildNumber = values as? Int else {
                return .failure(.typecastFailed("integer", metadata: [self, #file, #function, #line]))
            }

            return .success(appStoreBuildNumber)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getRedirectionKey() async -> Callback<String, Exception> {
        let getValuesResult = await database.getValues(
            at: MetadataServiceKey.redirectionKey.path,
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let redirectionKey = values as? String else {
                return .failure(.typecastFailed("string", metadata: [self, #file, #function, #line]))
            }

            return .success(redirectionKey)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getShouldForceUpdate() async -> Callback<Bool, Exception> {
        let getValuesResult = await database.getValues(
            at: MetadataServiceKey.shouldForceUpdate.path,
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let shouldForceUpdate = values as? Bool else {
                return .failure(.typecastFailed("Bool", metadata: [self, #file, #function, #line]))
            }

            return .success(shouldForceUpdate)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getStorageReferenceURL() async -> Callback<URL, Exception> {
        let getValuesResult = await database.getValues(
            at: MetadataServiceKey.storageReferenceURL.path,
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let urlString = values as? String,
                  let storageReferenceURL = URL(string: urlString) else {
                return .failure(.typecastFailed("URL", metadata: [self, #file, #function, #line]))
            }

            return .success(storageReferenceURL)

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
