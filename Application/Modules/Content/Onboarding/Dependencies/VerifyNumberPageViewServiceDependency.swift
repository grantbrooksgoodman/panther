//
//  VerifyNumberPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum VerifyNumberPageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> VerifyNumberPageViewService {
        .init()
    }
}

public extension DependencyValues {
    var verifyNumberPageViewService: VerifyNumberPageViewService {
        get { self[VerifyNumberPageViewServiceDependency.self] }
        set { self[VerifyNumberPageViewServiceDependency.self] = newValue }
    }
}
