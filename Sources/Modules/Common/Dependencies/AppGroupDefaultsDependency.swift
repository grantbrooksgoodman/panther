//
//  AppGroupDefaultsDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum AppGroupDefaultsDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> UserDefaults {
        .init(suiteName: NotificationExtensionConstants.appGroupDefaultsSuiteName) ?? .init()
    }
}

extension DependencyValues {
    var appGroupDefaults: UserDefaults {
        get { self[AppGroupDefaultsDependency.self] }
        set { self[AppGroupDefaultsDependency.self] = newValue }
    }
}
