//
//  PhoneNumberKitDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import PhoneNumberKit

enum PhoneNumberKitDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> PhoneNumberKit.PhoneNumberUtility {
        .init()
    }
}

extension DependencyValues {
    var phoneNumberKit: PhoneNumberKit.PhoneNumberUtility {
        get { self[PhoneNumberKitDependency.self] }
        set { self[PhoneNumberKitDependency.self] = newValue }
    }
}
