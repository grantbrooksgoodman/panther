//
//  SharedStates.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 28/07/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

// swiftformat:disable wrapPropertyBodies

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Use this extension to declare app-specific ``StateStream`` values for
/// cross-scope communication.
///
/// Define each value as a computed property:
///
/// ```swift
/// extension SharedStates {
///     var isLoggedIn: StateStream<Bool> { state(false) }
/// }
/// ```
///
/// Access a ``StateStream`` through the ``SharedState`` property wrapper:
///
/// ```swift
/// @SharedState(\.isLoggedIn) private var isLoggedIn
///
/// isLoggedIn = true
/// ```
///
/// Subscribe view models with ``ViewModelOf/observing(_:_:)``, or iterate
/// the ``StateStream/changes`` stream from services.
extension SharedStates {
    var didGrantAIEnhancedTranslationPermission: StateStream<Bool> { state(false) }
    var didGrantPenPalsPermission: StateStream<Bool> { state(false) }
    var isNewChatPageDoneToolbarButtonEnabled: StateStream<Bool> { state(true) }
    var reloadingConversationIDKeys: StateStream<Set<String>> { state([]) }
}

// swiftformat:enable wrapPropertyBodies
