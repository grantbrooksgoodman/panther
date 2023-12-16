//
//  MetadataService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public final class MetadataService {
    // MARK: - Types

    private enum MetadataServiceKey: String {
        /* MARK: Cases */

        case appShareLink
        case appStoreBuildNumber
        case pushAPIKey = "pushApiKey"
        case redirectionKey
        case shouldForceUpdate

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
    public private(set) var pushAPIKey: String?
    public private(set) var redirectionKey: String?
    public private(set) var shouldForceUpdate: Bool?

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

        if pushAPIKey == nil {
            let getPushAPIKeyResult = await getPushAPIKey()

            switch getPushAPIKeyResult {
            case let .success(pushAPIKey):
                self.pushAPIKey = pushAPIKey

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
                return .failure(.init(
                    "Failed to typecast values to URL.",
                    metadata: [self, #file, #function, #line]
                ))
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
                return .failure(.init(
                    "Failed to typecast values to integer.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            return .success(appStoreBuildNumber)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getPushAPIKey() async -> Callback<String, Exception> {
        let getValuesResult = await database.getValues(
            at: MetadataServiceKey.pushAPIKey.path,
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let pushAPIKey = values as? String else {
                return .failure(.init(
                    "Failed to typecast values to string.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            return .success(pushAPIKey)

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
                return .failure(.init(
                    "Failed to typecast values to string.",
                    metadata: [self, #file, #function, #line]
                ))
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
                return .failure(.init(
                    "Failed to typecast values to Bool.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            return .success(shouldForceUpdate)

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
