//
//  ComponentKitDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import ComponentKit
import CoreArchitecture

public enum ComponentKitDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ComponentKit {
        .init()
    }
}

public extension DependencyValues {
    var componentKit: ComponentKit {
        get { self[ComponentKitDependency.self] }
        set { self[ComponentKitDependency.self] = newValue }
    }
}
