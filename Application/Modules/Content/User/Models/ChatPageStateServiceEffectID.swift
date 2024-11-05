//
//  ChatPageStateServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ChatPageStateServiceEffectID: Hashable {
    // MARK: - Properties

    public let rawValue: String

    // MARK: - Init

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension ChatPageStateServiceEffectID {
    static let deeplinkToOtherChat: ChatPageStateServiceEffectID = .init("deeplinkToOtherChat")
    static let updateAppearance: ChatPageStateServiceEffectID = .init("updateAppearance")
    static let updateConversations: ChatPageStateServiceEffectID = .init("updateConversations")
    static let updateCurrentUser: ChatPageStateServiceEffectID = .init("updateCurrentUser")
}
