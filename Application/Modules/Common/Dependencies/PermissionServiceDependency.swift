//
//  PermissionServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum PermissionServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> PermissionService {
        .init()
    }
}

public extension DependencyValues {
    var permissionService: PermissionService {
        get { self[PermissionServiceDependency.self] }
        set { self[PermissionServiceDependency.self] = newValue }
    }
}
