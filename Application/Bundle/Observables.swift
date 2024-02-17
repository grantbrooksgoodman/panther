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
    case newChatSheetDismissed
    case traitCollectionChanged
    case translatedInvitationPending
    case updatedContactPairArchive
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
    public static let newChatSheetDismissed: Observable<Nil> = .init(key: .newChatSheetDismissed)
    public static let traitCollectionChanged: Observable<Nil> = .init(key: .traitCollectionChanged)
    public static let translatedInvitationPending: Observable<Nil> = .init(key: .translatedInvitationPending)
    public static let updatedContactPairArchive: Observable<Nil> = .init(key: .updatedContactPairArchive)
    public static let updatedCurrentUser: Observable<Nil> = .init(key: .updatedCurrentUser)
}
