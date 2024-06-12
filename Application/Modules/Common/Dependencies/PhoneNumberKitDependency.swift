//
//  PhoneNumberKitDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import PhoneNumberKit

public enum PhoneNumberKitDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> PhoneNumberKit {
        .init()
    }
}

public extension DependencyValues {
    var phoneNumberKit: PhoneNumberKit {
        get { self[PhoneNumberKitDependency.self] }
        set { self[PhoneNumberKitDependency.self] = newValue }
    }
}
