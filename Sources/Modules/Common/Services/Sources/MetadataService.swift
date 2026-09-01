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
import Networking

/// Use ``MetadataService`` to read app configuration values hosted in the remote database.
///
/// Each value is persisted across launches and served immediately through its corresponding
/// property. Call ``resolveValues()`` to revalidate the persisted snapshot against the network
/// once per session, so callers converge on authoritative data without blocking on the fetch.
struct MetadataService: GeminiAPIKeyDelegate {
    // MARK: - Types

    private enum MetadataServiceKey: String {
        /* MARK: Cases */

        case appShareLink
        case appStoreBuildNumber
        case geminiAPIKey = "geminiApiKey"
        case isPrevaricationModeEnabled
        case redirectionKey
        case shouldForceUpdate
        case storageReferenceURL

        /* MARK: Properties */

        var path: String {
            "\(NetworkPath.shared.rawValue)/\(rawValue)"
        }
    }

    // MARK: - Dependencies

    @Dependency(\.networking.database) private var database: DatabaseDelegate

    // MARK: - Properties

    /// The shared metadata service instance.
    static let shared = MetadataService()

    /// The app's share link, or `nil` if it has not been resolved.
    @Persistent(.appShareLink) private(set) var appShareLink: URL?

    /// The App Store build number, or `nil` if it has not been resolved.
    @Persistent(.appStoreBuildNumber) private(set) var appStoreBuildNumber: Int?

    /// The Gemini API key, or `nil` if it has not been resolved.
    @Persistent(.geminiAPIKey) private(set) var geminiAPIKey: String?

    /// A Boolean value that indicates whether prevarication mode may be enabled, or `nil` if it
    /// has not been resolved.
    @Persistent(.isPrevaricationModeEnabled) private(set) var isPrevaricationModeEnabled: Bool?

    /// The hosted redirection key, or `nil` if it has not been resolved.
    @Persistent(.redirectionKey) private(set) var redirectionKey: String?

    /// A Boolean value that indicates whether the app should force an update, or `nil` if it
    /// has not been resolved.
    @Persistent(.shouldForceUpdate) private(set) var shouldForceUpdate: Bool?

    /// The base URL for browsing remote storage, or `nil` if it has not been resolved.
    @Persistent(.storageReferenceURL) private(set) var storageReferenceURL: URL?

    private static let coalescer = SingleSlotCoalescer<Void>()

    // MARK: - Computed Properties

    /// The Gemini API key, or an empty string if it has not been resolved.
    var apiKey: String {
        geminiAPIKey ?? ""
    }

    private var canRevalidate: Bool {
        appShareLink == nil ||
            appStoreBuildNumber == nil ||
            geminiAPIKey == nil ||
            isPrevaricationModeEnabled == nil ||
            redirectionKey == nil ||
            shouldForceUpdate == nil ||
            storageReferenceURL == nil
    }

    // MARK: - Init

    private init() {
        Networking.config.registerGeminiAPIKeyDelegate(self)
    }

    // MARK: - Resolve All Values

    /// Revalidates the hosted values against the network, overwriting the persisted snapshot.
    ///
    /// The persisted values are served immediately on launch. Concurrent calls coalesce onto a
    /// single in-flight refresh, and subsequent calls within the session return immediately.
    ///
    /// - Throws: An `Exception` if fetching fails, or if a hosted value is missing or of an
    ///   unexpected type.
    func resolveValues() async throws(Exception) {
        guard canRevalidate else { return }
        try await Self.coalescer { () async throws(Exception) in
            guard canRevalidate else { return }
            try await assignValues(
                from: database.getValues(
                    at: NetworkPath.shared.rawValue,
                    prependingEnvironment: false,
                    cacheStrategy: .returnCacheOnFailure
                )
            )
        }
    }

    // MARK: - Auxiliary

    private func assignValues(
        from dictionary: [String: Any]
    ) throws(Exception) {
        guard let appShareLink = (dictionary[
            MetadataServiceKey.appShareLink.rawValue
        ] as? String).flatMap({ URL(string: $0) }) else {
            throw Exception.Networking.typecastFailed(
                "URL",
                metadata: .init(sender: self)
            )
        }

        guard let storageReferenceURL = (dictionary[
            MetadataServiceKey.storageReferenceURL.rawValue
        ] as? String).flatMap({ URL(string: $0) }) else {
            throw Exception.Networking.typecastFailed(
                "URL",
                metadata: .init(sender: self)
            )
        }

        guard let appStoreBuildNumber = dictionary[
            MetadataServiceKey.appStoreBuildNumber.rawValue
        ] as? Int else {
            throw Exception.Networking.typecastFailed(
                "integer",
                metadata: .init(sender: self)
            )
        }

        guard let geminiAPIKey = dictionary[
            MetadataServiceKey.geminiAPIKey.rawValue
        ] as? String else {
            throw Exception.Networking.typecastFailed(
                "string",
                metadata: .init(sender: self)
            )
        }

        guard let redirectionKey = dictionary[
            MetadataServiceKey.redirectionKey.rawValue
        ] as? String else {
            throw Exception.Networking.typecastFailed(
                "string",
                metadata: .init(sender: self)
            )
        }

        guard let isPrevaricationModeEnabled = dictionary[
            MetadataServiceKey.isPrevaricationModeEnabled.rawValue
        ] as? Bool else {
            throw Exception.Networking.typecastFailed(
                "Bool",
                metadata: .init(sender: self)
            )
        }

        guard let shouldForceUpdate = dictionary[
            MetadataServiceKey.shouldForceUpdate.rawValue
        ] as? Bool else {
            throw Exception.Networking.typecastFailed(
                "Bool",
                metadata: .init(sender: self)
            )
        }

        self.appShareLink = appShareLink
        self.appStoreBuildNumber = appStoreBuildNumber
        self.geminiAPIKey = geminiAPIKey
        self.isPrevaricationModeEnabled = isPrevaricationModeEnabled
        self.redirectionKey = redirectionKey
        self.shouldForceUpdate = shouldForceUpdate
        self.storageReferenceURL = storageReferenceURL
    }
}
