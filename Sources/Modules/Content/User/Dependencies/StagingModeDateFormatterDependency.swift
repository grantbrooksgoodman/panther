//
//  StagingModeDateFormatterDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/06/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum StagingModeDateFormatterDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter
    }
}

extension DependencyValues {
    var stagingModeDateFormatter: DateFormatter {
        get { self[StagingModeDateFormatterDependency.self] }
        set { self[StagingModeDateFormatterDependency.self] = newValue }
    }
}
