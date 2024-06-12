//
//  FirebaseMessagingDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
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
