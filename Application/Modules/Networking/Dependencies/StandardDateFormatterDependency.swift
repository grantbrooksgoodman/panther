//
//  StandardDateFormatterDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum StandardDateFormatterDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        dateFormatter.locale = .init(identifier: "en_US")
        return dateFormatter
    }
}

public extension DependencyValues {
    var standardDateFormatter: DateFormatter {
        get { self[StandardDateFormatterDependency.self] }
        set { self[StandardDateFormatterDependency.self] = newValue }
    }
}
