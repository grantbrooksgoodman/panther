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

/// A build information string displayed by the build info button.
///
/// The build info button cycles through a fixed sequence of strings describing the running
/// build; use ``next`` to advance to the following entry.
struct BuildInfoButtonStrings: Equatable {
    // MARK: - Types

    /// A kind of build information string.
    enum BuildInfoButtonStringKey: Equatable {
        /// The bundle version with its build number and revision.
        case bundleVersionAndBuildNumber

        /// The build SKU.
        case buildSKU

        /// The project ID.
        case projectID

        /// The current user's ID with the network environment.
        case userIDAndNetworkEnvironment

        /// The copyright notice.
        case copyright
    }

    // MARK: - Properties

    /// The kind of string this instance represents.
    let key: BuildInfoButtonStringKey

    /// The text the build info button displays.
    let labelText: String

    // MARK: - Computed Properties

    /// The strings for the next entry in the display sequence.
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

    /// Creates the strings for the given key.
    ///
    /// - Parameter key: The kind of string to create.
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
