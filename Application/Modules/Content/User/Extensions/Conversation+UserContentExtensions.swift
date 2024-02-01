//
//  Conversation+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Conversation {
    var isMock: Bool { id.key == UserContentConstants.newConversationID }

    var withMessagesSortedBySentDate: Conversation {
        .init(
            id,
            messageIDs: messageIDs,
            messages: messages?.sortedBySentDate,
            lastModifiedDate: lastModifiedDate,
            participants: participants,
            users: users
        )
    }
}
