//
//  PhoneNumberServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum PhoneNumberServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> PhoneNumberService {
        .init()
    }
}

public extension DependencyValues {
    var phoneNumberService: PhoneNumberService {
        get { self[PhoneNumberServiceDependency.self] }
        set { self[PhoneNumberServiceDependency.self] = newValue }
    }
}
