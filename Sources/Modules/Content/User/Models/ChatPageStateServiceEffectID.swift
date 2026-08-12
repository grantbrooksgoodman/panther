//
//  ChatPageStateServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A unique identifier for an effect registered with `ChatPageStateService`.
struct ChatPageStateServiceEffectID: Hashable {
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

extension ChatPageStateServiceEffectID {
    static let deeplinkToOtherChat: ChatPageStateServiceEffectID = .init("deeplinkToOtherChat")
    static let markConversationStale: ChatPageStateServiceEffectID = .init("markConversationStale")
    static let updateAppearance: ChatPageStateServiceEffectID = .init("updateAppearance")
}
