//
//  ContactServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum ContactServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ContactService {
        .init()
    }
}

public extension DependencyValues {
    var contactService: ContactService {
        get { self[ContactServiceDependency.self] }
        set { self[ContactServiceDependency.self] = newValue }
    }
}
