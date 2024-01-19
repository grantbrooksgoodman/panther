//
//  Observables.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import Redux

public enum ObservableKey: String {
    // MARK: - App Cases

    /* Add cases here to define new values for Observer instances. */

    case isNetworkActivityOccurring
    case updatedCurrentUser

    // MARK: - Core Cases

    case breadcrumbsDidCapture
    case isDeveloperModeEnabled
    case rootViewToast
    case rootViewToastAction
    case themedViewAppearanceChanged
}

/// For sending and accessing observed values between scopes.
public enum Observables {
    /* Add new properties conforming to Observable here. */

    public static let isNetworkActivityOccurring: Observable<Bool> = .init(.isNetworkActivityOccurring, false)
    public static let updatedCurrentUser: Observable<Nil> = .init(key: .updatedCurrentUser)
}
