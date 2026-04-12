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
import Networking

struct BuildInfoButtonStrings: Equatable {
    // MARK: - Types

    enum BuildInfoButtonStringKey: Equatable {
        case bundleVersionAndBuildNumber
        case buildSKU
        case projectID
        case userIDAndNetworkEnvironment
        case copyright
    }

    // MARK: - Properties

    let key: BuildInfoButtonStringKey
    let labelText: String

    // MARK: - Computed Properties

    var next: BuildInfoButtonStrings {
        switch key {
        case .bundleVersionAndBuildNumber:
            .init(.buildSKU)

        case .buildSKU:
            .init(.projectID)

        case .projectID:
            .init(.userIDAndNetworkEnvironment)

        case .userIDAndNetworkEnvironment:
            .init(.copyright)

        case .copyright:
            .init(.bundleVersionAndBuildNumber)
        }
    }

    // MARK: - Init

    init(_ key: BuildInfoButtonStringKey) {
        @Dependency(\.build) var build: Build
        @Dependency(\.currentCalendar) var calendar: Calendar

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
            labelText = "\(User.currentUserID ?? "�") | \(Networking.config.environment.shortString)"

        case .copyright:
            labelText = "Copyright © \(calendar.component(.year, from: Date.now)) NEOTechnica Corp."
        }
    }
}
