//
//  InputBarConfigServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum InputBarConfigServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> InputBarConfigService {
        .init()
    }
}

public extension DependencyValues {
    var inputBarConfigService: InputBarConfigService {
        get { self[InputBarConfigServiceDependency.self] }
        set { self[InputBarConfigServiceDependency.self] = newValue }
    }
}
