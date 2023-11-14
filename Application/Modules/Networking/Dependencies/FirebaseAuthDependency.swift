//
//  FirebaseAuthDependency.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 11/9/23.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseAuth
import Redux

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
