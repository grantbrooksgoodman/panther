//
//  CNContactStoreDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation

/* Proprietary */
import AppSubsystem

public enum CNContactStoreDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> CNContactStore {
        .init()
    }
}

public extension DependencyValues {
    var cnContactStore: CNContactStore {
        get { self[CNContactStoreDependency.self] }
        set { self[CNContactStoreDependency.self] = newValue }
    }
}
