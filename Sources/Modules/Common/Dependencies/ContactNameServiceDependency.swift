//
//  ContactNameServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum ContactNameServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> ContactNameService {
        .init()
    }
}

extension DependencyValues {
    var contactNameService: ContactNameService {
        get { self[ContactNameServiceDependency.self] }
        set { self[ContactNameServiceDependency.self] = newValue }
    }
}
