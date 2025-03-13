//
//  FirebaseMessagingDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseMessaging

public enum FirebaseMessagingDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> Messaging {
        Messaging.messaging()
    }
}

public extension DependencyValues {
    var firebaseMessaging: Messaging {
        get { self[FirebaseMessagingDependency.self] }
        set { self[FirebaseMessagingDependency.self] = newValue }
    }
}
