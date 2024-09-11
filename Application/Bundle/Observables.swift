//
//  Observables.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension ObservableKey {
    /* Add keys here to define new values for Observer instances. */

    static let contactSelectorPresentationPending: ObservableKey = .init("contactSelectorPresentationPending")
    static let isNetworkActivityOccurring: ObservableKey = .init("isNetworkActivityOccurring")
    static let networkActivityOccurred: ObservableKey = .init("networkActivityOccurred")
    static let newChatSheetDismissed: ObservableKey = .init("newChatSheetDismissed")
    static let traitCollectionChanged: ObservableKey = .init("traitCollectionChanged")
    static let updatedContactPairArchive: ObservableKey = .init("updatedContactPairArchive")
    static let updatedCurrentUser: ObservableKey = .init("updatedCurrentUser")
}

/// For sending and accessing observed values between scopes.
public extension Observables {
    /* Add new properties conforming to Observable here. */

    static let contactSelectorPresentationPending: Observable<Nil> = .init(key: .contactSelectorPresentationPending)
    static let isNetworkActivityOccurring: Observable<Bool> = .init(.isNetworkActivityOccurring, false)
    static let networkActivityOccurred: Observable<Nil> = .init(key: .networkActivityOccurred)
    static let newChatSheetDismissed: Observable<Nil> = .init(key: .newChatSheetDismissed)
    static let traitCollectionChanged: Observable<Nil> = .init(key: .traitCollectionChanged)
    static let updatedContactPairArchive: Observable<Nil> = .init(key: .updatedContactPairArchive)
    static let updatedCurrentUser: Observable<Nil> = .init(key: .updatedCurrentUser)
}
