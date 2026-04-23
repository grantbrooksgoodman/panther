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

/// For sending and accessing observed values between scopes.
extension Observables {
    /* Add new properties conforming to Observable here. */

    static let chatInfoPageLoadingStateUpdated = Observable<Nil>()
    static let currentConversationActivityChanged = Observable<Nil>()
    static let currentConversationMetadataChanged = Observable<Nil>()
    static let didGrantAIEnhancedTranslationPermission = Observable<Bool>(false)
    static let didGrantPenPalsPermission = Observable<Bool>(false)
    static let firstMessageSentInNewChat = Observable<Nil>()
    static let isNewChatPageDoneToolbarButtonEnabled = Observable<Bool>(true)
    static let networkActivityOccurred = Observable<Nil>()
    static let newChatPagePenPalsToolbarButtonAnimation = Observable<Nil>()
    static let traitCollectionChanged = Observable<Nil>()
    static let updatedContactPairArchive = Observable<Nil>()
    static let updatedCurrentUser = Observable<Nil>()
}
