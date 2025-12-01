//
//  SettingsPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum SettingsPageViewServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> SettingsPageViewService {
        .init()
    }
}

extension DependencyValues {
    var settingsPageViewService: SettingsPageViewService {
        get { self[SettingsPageViewServiceDependency.self] }
        set { self[SettingsPageViewServiceDependency.self] = newValue }
    }
}
