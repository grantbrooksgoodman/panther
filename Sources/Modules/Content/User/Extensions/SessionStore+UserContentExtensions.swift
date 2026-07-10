//
//  SessionStore+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension SessionStore {
    // MARK: - Computed Properties

    /// ID keys of archived conversations hidden from the current user.
    var ignoredConversationIDKeys: [String] {
        conversations.values
            .filter { !$0.isVisibleForCurrentUser }
            .map(\.id.key)
    }
}
