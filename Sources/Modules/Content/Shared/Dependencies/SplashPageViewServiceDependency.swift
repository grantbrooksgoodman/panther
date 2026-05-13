//
//  SplashPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum SplashPageViewServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> SplashPageViewService {
        // swiftformat:disable all
        @MainActorIsolated var splashPageViewService = SplashPageViewService()
        return splashPageViewService // swiftformat:enable all
    }
}

extension DependencyValues {
    var splashPageViewService: SplashPageViewService {
        get { self[SplashPageViewServiceDependency.self] }
        set { self[SplashPageViewServiceDependency.self] = newValue }
    }
}
