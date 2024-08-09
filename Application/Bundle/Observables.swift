//
//  Observables.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum ObservableKey: String {
    // MARK: - App Cases

    /* Add cases here to define new values for Observer instances. */

    case contactSelectorPresentationPending
    case isNetworkActivityOccurring
    case networkActivityOccurred
    case newChatSheetDismissed
    case traitCollectionChanged
    case updatedContactPairArchive
    case updatedCurrentUser

    // MARK: - Core Cases

    case breadcrumbsDidCapture
    case isDeveloperModeEnabled
    case languageCodeChanged
    case rootViewSheet
    case rootViewToast
    case rootViewToastAction
    case themedViewAppearanceChanged
}

/// For sending and accessing observed values between scopes.
public enum Observables {
    /* Add new properties conforming to Observable here. */

    public static let contactSelectorPresentationPending: Observable<Nil> = .init(key: .contactSelectorPresentationPending)
    public static let isNetworkActivityOccurring: Observable<Bool> = .init(.isNetworkActivityOccurring, false)
    public static let networkActivityOccurred: Observable<Nil> = .init(key: .networkActivityOccurred)
    public static let newChatSheetDismissed: Observable<Nil> = .init(key: .newChatSheetDismissed)
    public static let traitCollectionChanged: Observable<Nil> = .init(key: .traitCollectionChanged)
    public static let updatedContactPairArchive: Observable<Nil> = .init(key: .updatedContactPairArchive)
    public static let updatedCurrentUser: Observable<Nil> = .init(key: .updatedCurrentUser)
}
