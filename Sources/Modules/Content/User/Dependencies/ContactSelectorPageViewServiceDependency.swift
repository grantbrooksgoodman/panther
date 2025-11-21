//
//  ContactSelectorPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum ContactSelectorPageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ContactSelectorPageViewService {
        .init()
    }
}

public extension DependencyValues {
    var contactSelectorPageViewService: ContactSelectorPageViewService {
        get { self[ContactSelectorPageViewServiceDependency.self] }
        set { self[ContactSelectorPageViewServiceDependency.self] = newValue }
    }
}
