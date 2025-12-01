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

enum FirebaseMessagingDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> Messaging {
        Messaging.messaging()
    }
}

extension DependencyValues {
    var firebaseMessaging: Messaging {
        get { self[FirebaseMessagingDependency.self] }
        set { self[FirebaseMessagingDependency.self] = newValue }
    }
}
