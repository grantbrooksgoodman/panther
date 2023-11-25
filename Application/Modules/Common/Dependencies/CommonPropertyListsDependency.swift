//
//  CommonPropertyListsDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum CommonPropertyListsDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> CommonPropertyLists {
        .init()
    }
}

public extension DependencyValues {
    var commonPropertyLists: CommonPropertyLists {
        get { self[CommonPropertyListsDependency.self] }
        set { self[CommonPropertyListsDependency.self] = newValue }
    }
}
