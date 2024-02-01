//
//  InputBarAccessoryViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum InputBarAccessoryViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> InputBarAccessoryViewService {
        .init()
    }
}

public extension DependencyValues {
    var inputBarAccessoryViewService: InputBarAccessoryViewService {
        get { self[InputBarAccessoryViewServiceDependency.self] }
        set { self[InputBarAccessoryViewServiceDependency.self] = newValue }
    }
}
