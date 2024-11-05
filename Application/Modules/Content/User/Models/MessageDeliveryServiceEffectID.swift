//
//  MessageDeliveryServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct MessageDeliveryServiceEffectID: Hashable {
    // MARK: - Properties

    public let rawValue: String

    // MARK: - Init

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension MessageDeliveryServiceEffectID {
    static let reloadCollectionView: MessageDeliveryServiceEffectID = .init("reloadCollectionView")
    static let updateIsTypingForCurrentUser: MessageDeliveryServiceEffectID = .init("updateIsTypingForCurrentUser")
}
