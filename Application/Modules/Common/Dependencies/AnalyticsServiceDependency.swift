//
//  AnalyticsServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum AnalyticsServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> AnalyticsService {
        .init()
    }
}

public extension DependencyValues {
    var analyticsService: AnalyticsService {
        get { self[AnalyticsServiceDependency.self] }
        set { self[AnalyticsServiceDependency.self] = newValue }
    }
}
