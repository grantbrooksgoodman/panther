//
//  ActivityAction+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension Activity.Action {
    /// A Boolean value that indicates whether the action added the current user to a conversation.
    var isCurrentUserAdded: Bool {
        switch self {
        case let .addedToConversation(userID: userID): userID == User.currentUserID
        default: false
        }
    }
}
