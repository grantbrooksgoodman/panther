//
//  UserNotificationCenterDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UserNotifications

/* Proprietary */
import AppSubsystem

enum UserNotificationCenterDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> UNUserNotificationCenter {
        .current()
    }
}

extension DependencyValues {
    var userNotificationCenter: UNUserNotificationCenter {
        get { self[UserNotificationCenterDependency.self] }
        set { self[UserNotificationCenterDependency.self] = newValue }
    }
}
