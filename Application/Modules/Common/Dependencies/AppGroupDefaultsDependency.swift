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

public enum AppGroupDefaultsDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> UserDefaults {
        .init(suiteName: NotificationExtensionConstants.appGroupDefaultsSuiteName) ?? .init()
    }
}

public extension DependencyValues {
    var appGroupDefaults: UserDefaults {
        get { self[AppGroupDefaultsDependency.self] }
        set { self[AppGroupDefaultsDependency.self] = newValue }
    }
}
