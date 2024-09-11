//
//  FirebaseAuthDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseAuth

public enum FirebaseAuthDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> FirebaseAuth.Auth {
        .auth()
    }
}

public extension DependencyValues {
    var firebaseAuth: FirebaseAuth.Auth {
        get { self[FirebaseAuthDependency.self] }
        set { self[FirebaseAuthDependency.self] = newValue }
    }
}
