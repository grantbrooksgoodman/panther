//
//  ChangeLanguagePageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum ChangeLanguagePageViewServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> ChangeLanguagePageViewService {
        .init()
    }
}

extension DependencyValues {
    var changeLanguagePageViewService: ChangeLanguagePageViewService {
        get { self[ChangeLanguagePageViewServiceDependency.self] }
        set { self[ChangeLanguagePageViewServiceDependency.self] = newValue }
    }
}
