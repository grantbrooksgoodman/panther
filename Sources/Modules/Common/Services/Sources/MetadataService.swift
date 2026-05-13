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

final class MetadataService: GeminiAPIKeyDelegate, @unchecked Sendable {
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

    static let shared = MetadataService()

    private(set) var appShareLink: URL?
    private(set) var appStoreBuildNumber: Int?
    private(set) var geminiAPIKey: String?
    private(set) var isPrevaricationModeEnabled: Bool?
    private(set) var redirectionKey: String?
    private(set) var shouldForceUpdate: Bool?
    private(set) var storageReferenceURL: URL?

    // MARK: - Computed Properties

    var apiKey: String {
        geminiAPIKey ?? ""
    }

    // MARK: - Init

    private init() {
        Networking.config.registerGeminiAPIKeyDelegate(self)
    }

    // MARK: - Resolve All Values

    func resolveValues() async -> Exception? {
        guard appShareLink == nil
            || appStoreBuildNumber == nil
            || geminiAPIKey == nil
            || isPrevaricationModeEnabled == nil
            || redirectionKey == nil
            || shouldForceUpdate == nil
            || storageReferenceURL == nil else { return nil }

        do {
            let sharedData: [String: Any] = try await database.getValues(
                at: NetworkPath.shared.rawValue,
                prependingEnvironment: false
            )
            return assignValues(from: sharedData)
        } catch {
            return error
        }
    }

    // MARK: - Auxiliary

    private func assignValues(from dictionary: [String: Any]) -> Exception? {
        if appShareLink == nil {
            guard let urlString = dictionary[
                MetadataServiceKey.appShareLink.rawValue
            ] as? String,
                let url = URL(string: urlString) else {
                return .Networking.typecastFailed(
                    "URL",
                    metadata: .init(sender: self)
                )
            }

            appShareLink = url
        }

        if appStoreBuildNumber == nil {
            guard let value = dictionary[
                MetadataServiceKey.appStoreBuildNumber.rawValue
            ] as? Int else {
                return .Networking.typecastFailed(
                    "integer",
                    metadata: .init(sender: self)
                )
            }

            appStoreBuildNumber = value
        }

        if geminiAPIKey == nil {
            guard let value = dictionary[
                MetadataServiceKey.geminiAPIKey.rawValue
            ] as? String else {
                return .Networking.typecastFailed(
                    "string",
                    metadata: .init(sender: self)
                )
            }

            geminiAPIKey = value
        }

        if isPrevaricationModeEnabled == nil {
            guard let value = dictionary[
                MetadataServiceKey.isPrevaricationModeEnabled.rawValue
            ] as? Bool else {
                return .Networking.typecastFailed(
                    "Bool",
                    metadata: .init(sender: self)
                )
            }

            isPrevaricationModeEnabled = value
        }

        if redirectionKey == nil {
            guard let value = dictionary[
                MetadataServiceKey.redirectionKey.rawValue
            ] as? String else {
                return .Networking.typecastFailed(
                    "string",
                    metadata: .init(sender: self)
                )
            }

            redirectionKey = value
        }

        if shouldForceUpdate == nil {
            guard let value = dictionary[
                MetadataServiceKey.shouldForceUpdate.rawValue
            ] as? Bool else {
                return .Networking.typecastFailed(
                    "Bool",
                    metadata: .init(sender: self)
                )
            }

            shouldForceUpdate = value
        }

        if storageReferenceURL == nil {
            guard let value = dictionary[
                MetadataServiceKey.storageReferenceURL.rawValue
            ] as? String,
                let url = URL(string: value) else {
                return .Networking.typecastFailed(
                    "URL",
                    metadata: .init(sender: self)
                )
            }

            storageReferenceURL = url
        }

        return nil
    }
}
