//
//  RegionDetailServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum RegionDetailServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> RegionDetailService {
        .init()
    }
}

public extension DependencyValues {
    var regionDetailService: RegionDetailService {
        get { self[RegionDetailServiceDependency.self] }
        set { self[RegionDetailServiceDependency.self] = newValue }
    }
}
