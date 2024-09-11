//
//  FirebaseDatabaseDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseDatabase

public enum FirebaseDatabaseDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> DatabaseReference {
        FirebaseDatabase.Database.database().reference()
    }
}

public extension DependencyValues {
    var firebaseDatabase: DatabaseReference {
        get { self[FirebaseDatabaseDependency.self] }
        set { self[FirebaseDatabaseDependency.self] = newValue }
    }
}
