//
//  BuildInfoButtonStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 26/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct BuildInfoButtonStrings: Equatable {
    // MARK: - Types

    public enum BuildInfoButtonStringKey: Equatable {
        case bundleVersionAndBuildNumber
        case buildSKU
        case projectID
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
            return .init(.copyright)

        case .copyright:
            return .init(.bundleVersionAndBuildNumber)
        }
    }

    // MARK: - Init

    public init(_ key: BuildInfoButtonStringKey) {
        @Dependency(\.build) var build: Build
        @Dependency(\.currentCalendar) var calendar: Calendar
        @Localized(.version) var localizedVersionString: String

        self.key = key

        switch key {
        case .bundleVersionAndBuildNumber:
            labelText = "\(localizedVersionString) \(build.bundleVersion) (\(String(build.buildNumber))\(build.stage.shortString))"

        case .buildSKU:
            labelText = build.buildSKU

        case .projectID:
            labelText = build.projectID

        case .copyright:
            labelText = "Copyright © \(calendar.component(.year, from: Date())) NEOTechnica Corp."
        }
    }
}
