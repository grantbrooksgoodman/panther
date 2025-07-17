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

public enum ChangeLanguagePageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ChangeLanguagePageViewService {
        .init()
    }
}

public extension DependencyValues {
    var changeLanguagePageViewService: ChangeLanguagePageViewService {
        get { self[ChangeLanguagePageViewServiceDependency.self] }
        set { self[ChangeLanguagePageViewServiceDependency.self] = newValue }
    }
}
