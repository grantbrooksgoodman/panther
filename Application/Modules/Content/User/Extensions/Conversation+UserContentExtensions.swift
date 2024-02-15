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
    static var empty: Conversation {
        .init(
            .init(key: "", hash: ""),
            messageIDs: [],
            messages: nil,
            lastModifiedDate: .init(),
            participants: [],
            users: nil
        )
    }

    var isEmpty: Bool { id.key.isBlank && id.hash.isBlank }
    var isMock: Bool { id.key == UserContentConstants.newConversationID }

    static var mock: Conversation {
        .init(
            .init(key: UserContentConstants.newConversationID, hash: ""),
            messageIDs: [],
            messages: nil,
            lastModifiedDate: .init(),
            participants: [],
            users: nil
        )
    }

    var withMessagesSortedByAscendingSentDate: Conversation {
        .init(
            id,
            messageIDs: messageIDs,
            messages: messages?.sortedByAscendingSentDate,
            lastModifiedDate: lastModifiedDate,
            participants: participants,
            users: users
        )
    }
}
