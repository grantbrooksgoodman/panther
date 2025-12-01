//
//  MessageDeliveryServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct MessageDeliveryServiceEffectID: Hashable {
    // MARK: - Properties

    let rawValue: String

    // MARK: - Init

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension MessageDeliveryServiceEffectID {
    static let configureInputBar: MessageDeliveryServiceEffectID = .init("configureInputBar")
    static let reloadCollectionView: MessageDeliveryServiceEffectID = .init("reloadCollectionView")
    static let updateConversations: MessageDeliveryServiceEffectID = .init("updateConversations")
    static let updateIsTypingForCurrentUser: MessageDeliveryServiceEffectID = .init("updateIsTypingForCurrentUser")
}
