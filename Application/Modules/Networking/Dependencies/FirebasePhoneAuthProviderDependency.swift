//
//  FirebasePhoneAuthProviderDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseAuth

public enum FirebasePhoneAuthProviderDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> PhoneAuthProvider {
        .provider()
    }
}

public extension DependencyValues {
    var firebasePhoneAuthProvider: PhoneAuthProvider {
        get { self[FirebasePhoneAuthProviderDependency.self] }
        set { self[FirebasePhoneAuthProviderDependency.self] = newValue }
    }
}
