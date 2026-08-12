//
//  MessageDeliveryServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A unique identifier for an effect registered with `MessageDeliveryService`.
struct MessageDeliveryServiceEffectID: Hashable {
    // MARK: - Properties

    /// The string that identifies the effect.
    let rawValue: String

    // MARK: - Init

    /// Creates an identifier with the given string.
    ///
    /// - Parameter rawValue: The string that identifies the effect.
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension MessageDeliveryServiceEffectID {
    static let configureInputBar: MessageDeliveryServiceEffectID = .init("configureInputBar")
    static let reloadCollectionView: MessageDeliveryServiceEffectID = .init("reloadCollectionView")
    static let updateChatInfoPageView: MessageDeliveryServiceEffectID = .init("updateChatInfoPageView")
    static let updateConversations: MessageDeliveryServiceEffectID = .init("updateConversations")
    static let updateIsTypingForCurrentUser: MessageDeliveryServiceEffectID = .init("updateIsTypingForCurrentUser")
}
