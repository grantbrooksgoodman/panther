//
//  FirebaseDatabaseDependency.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 23/10/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseDatabase
import Redux

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
