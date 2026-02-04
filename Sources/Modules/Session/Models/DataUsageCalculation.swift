//
//  DataUsageCalculation.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct DataUsageCalculation: Hashable {
    // MARK: - Properties

    let dataUsageInKilobytes: Int
    let date: Date

    // MARK: - Computed Properties

    static var empty: DataUsageCalculation {
        .init(
            dataUsage: 0,
            date: Date(timeIntervalSince1970: 0)
        )
    }

    var isExpired: Bool {
        abs(date.seconds(from: .now)) > 10
    }

    // MARK: - Init

    init(
        dataUsage dataUsageInKilobytes: Int,
        date: Date = .now
    ) {
        self.dataUsageInKilobytes = dataUsageInKilobytes
        self.date = date
    }
}
