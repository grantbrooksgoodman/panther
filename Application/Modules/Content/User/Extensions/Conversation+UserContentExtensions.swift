//
//  Conversation+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Conversation {
    // MARK: - Properties

    var currentUserParticipant: Participant? { participants.firstWithCurrentUserID }
    var isEmpty: Bool { id.key.isBlank && id.hash.isBlank }
    var isMock: Bool { id.key == CommonConstants.newConversationID }

    var withMessagesSortedByAscendingSentDate: Conversation {
        .init(
            id,
            messageIDs: messageIDs,
            messages: messages?.sortedByAscendingSentDate,
            metadata: metadata,
            participants: participants,
            reactionMetadata: reactionMetadata,
            users: users
        )
    }

    // MARK: - Methods

    static func empty(withUsers users: [User]) -> Conversation {
        .init(
            .init(key: "", hash: ""),
            messageIDs: [],
            messages: nil,
            metadata: .empty,
            participants: [],
            reactionMetadata: nil,
            users: users
        )
    }

    static func mock(withUsers users: [User]) -> Conversation {
        .init(
            .init(key: CommonConstants.newConversationID, hash: ""),
            messageIDs: [],
            messages: nil,
            metadata: .empty,
            participants: [],
            reactionMetadata: nil,
            users: users
        )
    }
}
