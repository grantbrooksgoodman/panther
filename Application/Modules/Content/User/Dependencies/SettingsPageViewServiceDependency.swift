//
//  SettingsPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum SettingsPageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> SettingsPageViewService {
        .init()
    }
}

public extension DependencyValues {
    var settingsPageViewService: SettingsPageViewService {
        get { self[SettingsPageViewServiceDependency.self] }
        set { self[SettingsPageViewServiceDependency.self] = newValue }
    }
}
