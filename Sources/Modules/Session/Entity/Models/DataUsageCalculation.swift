//
//  DataUsageCalculation.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A record of the app's data usage at a point in time.
struct DataUsageCalculation: Hashable {
    // MARK: - Properties

    /// The data usage, in kilobytes.
    let dataUsageInKilobytes: Int

    /// The date the data usage was calculated.
    let date: Date

    // MARK: - Computed Properties

    /// An empty data usage calculation.
    static var empty: DataUsageCalculation {
        .init(
            dataUsage: 0,
            date: Date(timeIntervalSince1970: 0)
        )
    }

    /// A Boolean value that indicates whether the calculation has expired.
    var isExpired: Bool {
        @Dependency(\.dataUsageService) var dataUsageService: DataUsageService
        return abs(date.seconds(from: .now)) > (dataUsageService.isApproachingDataUsageLimit ? 10 : 60)
    }

    // MARK: - Init

    /// Creates a data usage calculation with the given values.
    ///
    /// - Parameters:
    ///   - dataUsage: The data usage, in kilobytes.
    ///   - date: The date the data usage was calculated.
    init(
        dataUsage dataUsageInKilobytes: Int,
        date: Date = .now
    ) {
        self.dataUsageInKilobytes = dataUsageInKilobytes
        self.date = date
    }
}
