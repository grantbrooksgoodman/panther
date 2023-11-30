//
//  UpdateServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum UpdateServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> UpdateService {
        .init()
    }
}

public extension DependencyValues {
    var updateService: UpdateService {
        get { self[UpdateServiceDependency.self] }
        set { self[UpdateServiceDependency.self] = newValue }
    }
}
