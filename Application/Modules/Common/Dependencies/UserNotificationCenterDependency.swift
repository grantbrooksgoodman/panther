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

/* 3rd-party */
import Redux

public enum UserNotificationCenterDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> UNUserNotificationCenter {
        .current()
    }
}

public extension DependencyValues {
    var userNotificationCenter: UNUserNotificationCenter {
        get { self[UserNotificationCenterDependency.self] }
        set { self[UserNotificationCenterDependency.self] = newValue }
    }
}
