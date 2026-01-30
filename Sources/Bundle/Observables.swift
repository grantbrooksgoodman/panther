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

extension ObservableKey {
    /* Add keys here to define new values for Observer instances. */

    static let chatInfoPageLoadingStateUpdated: ObservableKey = .init("chatInfoPageLoadingStateUpdated")
    static let currentConversationActivityChanged: ObservableKey = .init("currentConversationActivityChanged")
    static let currentConversationMetadataChanged: ObservableKey = .init("currentConversationMetadataChanged")
    static let didGrantAIEnhancedTranslationPermission: ObservableKey = .init("didGrantAIEnhancedTranslationPermission")
    static let didGrantPenPalsPermission: ObservableKey = .init("didGrantPenPalsPermission")
    static let firstMessageSentInNewChat: ObservableKey = .init("firstMessageSentInNewChat")
    static let isNewChatPageDoneToolbarButtonEnabled: ObservableKey = .init("isNewChatPageDoneToolbarButtonEnabled")
    static let networkActivityOccurred: ObservableKey = .init("networkActivityOccurred")
    static let newChatPagePenPalsToolbarButtonAnimation: ObservableKey = .init("newChatPagePenPalsToolbarButtonAnimation")
    static let traitCollectionChanged: ObservableKey = .init("traitCollectionChanged")
    static let updatedContactPairArchive: ObservableKey = .init("updatedContactPairArchive")
    static let updatedCurrentUser: ObservableKey = .init("updatedCurrentUser")
}

/// For sending and accessing observed values between scopes.
extension Observables {
    /* Add new properties conforming to Observable here. */

    static let chatInfoPageLoadingStateUpdated: Observable<Nil> = .init(key: .chatInfoPageLoadingStateUpdated)
    static let currentConversationActivityChanged: Observable<Nil> = .init(key: .currentConversationActivityChanged)
    static let currentConversationMetadataChanged: Observable<Nil> = .init(key: .currentConversationMetadataChanged)
    static let didGrantAIEnhancedTranslationPermission: Observable<Bool> = .init(.didGrantAIEnhancedTranslationPermission, false)
    static let didGrantPenPalsPermission: Observable<Bool> = .init(.didGrantPenPalsPermission, false)
    static let firstMessageSentInNewChat: Observable<Nil> = .init(key: .firstMessageSentInNewChat)
    static let isNewChatPageDoneToolbarButtonEnabled: Observable<Bool> = .init(.isNewChatPageDoneToolbarButtonEnabled, true)
    static let networkActivityOccurred: Observable<Nil> = .init(key: .networkActivityOccurred)
    static let newChatPagePenPalsToolbarButtonAnimation: Observable<Nil> = .init(key: .newChatPagePenPalsToolbarButtonAnimation)
    static let traitCollectionChanged: Observable<Nil> = .init(key: .traitCollectionChanged)
    static let updatedContactPairArchive: Observable<Nil> = .init(key: .updatedContactPairArchive)
    static let updatedCurrentUser: Observable<Nil> = .init(key: .updatedCurrentUser)
}
