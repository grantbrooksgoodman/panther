//
//  FirebasePhoneAuthProviderDependency.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 11/9/23.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseAuth
import Redux

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
