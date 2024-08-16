//
//  ContactNameServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum ContactNameServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ContactNameService {
        .init()
    }
}

public extension DependencyValues {
    var contactNameService: ContactNameService {
        get { self[ContactNameServiceDependency.self] }
        set { self[ContactNameServiceDependency.self] = newValue }
    }
}
