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

enum CNContactStoreDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> CNContactStore {
        .init()
    }
}

extension DependencyValues {
    var cnContactStore: CNContactStore {
        get { self[CNContactStoreDependency.self] }
        set { self[CNContactStoreDependency.self] = newValue }
    }
}
