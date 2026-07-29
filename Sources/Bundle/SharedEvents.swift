//
//  SharedEvents.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

// swiftformat:disable wrapPropertyBodies

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Use this extension to declare app-specific ``EventStream`` values for
/// cross-scope communication.
///
/// Define each event as a computed property; `EventStream<Void>` suits
/// signals that carry no payload:
///
/// ```swift
/// extension SharedEvents {
///     var sessionDidExpire: EventStream<Void> { event() }
/// }
/// ```
///
/// Access an ``EventStream`` through the ``SharedEvent`` property
/// wrapper and send events with ``EventStream/send(_:)``:
///
/// ```swift
/// @SharedEvent(\.sessionDidExpire) private var sessionDidExpire
///
/// sessionDidExpire.send()
/// ```
///
/// Subscribe view models with ``ViewModelOf/observing(_:_:)``, or iterate
/// the ``EventStream/events`` stream from services.
extension SharedEvents {
    var chatInfoPageLoadingStateUpdated: EventStream<Void> { event() }
    var currentConversationActivityChanged: EventStream<Void> { event() }
    var currentConversationMetadataChanged: EventStream<Void> { event() }
    var firstMessageSentInNewChat: EventStream<Void> { event() }
    var messageOutboxDidChange: EventStream<Void> { event() }
    var networkActivityOccurred: EventStream<Void> { event() }
    var newChatPagePenPalsToolbarButtonAnimation: EventStream<Void> { event() }
    var sessionStoreDidChange: EventStream<SessionStoreChange> { event() }
    var traitCollectionChanged: EventStream<Void> { event() }
    var updatedContactPairArchive: EventStream<Void> { event() }
}

// swiftformat:enable wrapPropertyBodies
