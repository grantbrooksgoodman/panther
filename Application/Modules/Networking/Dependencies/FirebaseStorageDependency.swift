//
//  FirebaseStorageDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseStorage

public enum FirebaseStorageDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> StorageReference {
        FirebaseStorage.Storage.storage().reference()
    }
}

public extension DependencyValues {
    var firebaseStorage: StorageReference {
        get { self[FirebaseStorageDependency.self] }
        set { self[FirebaseStorageDependency.self] = newValue }
    }
}
