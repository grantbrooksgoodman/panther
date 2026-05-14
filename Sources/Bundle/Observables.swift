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

/// Use this extension to declare app-specific ``Observable`` values
/// for cross-scope communication.
///
/// Define each observable as a static property. Use a typed observable
/// to share a changing value, or `Observable<Nil>` to broadcast an
/// event with no payload:
///
/// ```swift
/// extension Observables {
///     static let isLoggedIn = Observable<Bool>(false)
///     static let sessionDidExpire = Observable<Nil>()
/// }
/// ```
///
/// Write to a typed observable's ``Observable/value`` property to
/// update it and notify all registered observers. For event-style
/// observables, call ``Observable/trigger()`` instead:
///
///     Observables.isLoggedIn.value = true
///     Observables.sessionDidExpire.trigger()
///
/// - SeeAlso: ``Observer``
extension Observables {
    static let chatInfoPageLoadingStateUpdated = Observable<Nil>()
    static let currentConversationActivityChanged = Observable<Nil>()
    static let currentConversationMetadataChanged = Observable<Nil>()
    static let didGrantAIEnhancedTranslationPermission = Observable<Bool>(false)
    static let didGrantPenPalsPermission = Observable<Bool>(false)
    static let firstMessageSentInNewChat = Observable<Nil>()
    static let isNewChatPageDoneToolbarButtonEnabled = Observable<Bool>(true)
    static let networkActivityOccurred = Observable<Nil>()
    static let newChatPagePenPalsToolbarButtonAnimation = Observable<Nil>()
    static let traitCollectionChanged = Observable<Nil>() // swiftlint:disable:next identifier_name
    static let updateConversationsListSetToReliableDataSource = Observable<Nil>()
    static let updatedContactPairArchive = Observable<Nil>()
    static let updatedCurrentUser = Observable<Nil>()
}
