//
//  SplashPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum SplashPageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> SplashPageViewService {
        .init()
    }
}

public extension DependencyValues {
    var splashPageViewService: SplashPageViewService {
        get { self[SplashPageViewServiceDependency.self] }
        set { self[SplashPageViewServiceDependency.self] = newValue }
    }
}
