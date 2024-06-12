//
//  FirebaseStorageDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
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
