//
//  BuildInfoButtonStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 26/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct BuildInfoButtonStrings: Equatable {
    // MARK: - Types

    public enum BuildInfoButtonStringKey: Equatable {
        case bundleVersionAndBuildNumber
        case buildSKU
        case projectID
        case userIDAndNetworkEnvironment
        case copyright
    }

    // MARK: - Properties

    public let key: BuildInfoButtonStringKey
    public let labelText: String

    // MARK: - Computed Properties

    public var next: BuildInfoButtonStrings {
        switch key {
        case .bundleVersionAndBuildNumber:
            return .init(.buildSKU)

        case .buildSKU:
            return .init(.projectID)

        case .projectID:
            return .init(.userIDAndNetworkEnvironment)

        case .userIDAndNetworkEnvironment:
            return .init(.copyright)

        case .copyright:
            return .init(.bundleVersionAndBuildNumber)
        }
    }

    // MARK: - Init

    public init(_ key: BuildInfoButtonStringKey) {
        @Dependency(\.build) var build: Build
        @Dependency(\.currentCalendar) var calendar: Calendar
        @Dependency(\.clientSession.user.currentUser?.id) var currentUserID: String?
        @Dependency(\.networking.config.environment) var networkEnvironment: NetworkEnvironment

        @Persistent(.currentUserID) var fallbackCurrentUserID: String?
        @Localized(.version) var localizedVersionString: String

        self.key = key

        switch key {
        case .bundleVersionAndBuildNumber: // swiftlint:disable:next line_length
            labelText = "\(localizedVersionString) \(build.bundleVersion) (\(String(build.buildNumber))\(build.milestone.shortString)/\(build.bundleRevision.lowercased()))"

        case .buildSKU:
            labelText = build.buildSKU

        case .projectID:
            labelText = "7B0U3X1V | \(build.projectID)"

        case .userIDAndNetworkEnvironment:
            labelText = "\(currentUserID ?? fallbackCurrentUserID ?? "�") | \(networkEnvironment.shortString)"

        case .copyright:
            labelText = "Copyright © \(calendar.component(.year, from: Date())) NEOTechnica Corp."
        }
    }
}
