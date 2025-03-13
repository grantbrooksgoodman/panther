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

    var isCurrentUserSharingPenPalsData: Bool {
        guard metadata.isPenPalsConversation else { return true }
        guard participants.count == 2,
              let currentUserPenPalsSharingData = metadata.penPalsSharingData.firstWithCurrentUserID else { return false }
        return currentUserPenPalsSharingData.isSharingPenPalsData
    }

    var isEmpty: Bool { id.key.isBlank && id.hash.isBlank }
    var isMock: Bool { id.key == CommonConstants.newConversationID }

    var isOtherUserSharingPenPalsData: Bool {
        guard metadata.isPenPalsConversation else { return true }
        guard participants.count == 2,
              let otherUser = users?.first,
              let otherUserPenPalsSharingData = metadata
              .penPalsSharingData
              .first(where: { $0.userID == otherUser.id }) else { return false }
        return otherUserPenPalsSharingData.isSharingPenPalsData
    }

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
            metadata: .empty(userIDs: users.map(\.id)),
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
            metadata: .empty(userIDs: users.map(\.id)),
            participants: [],
            reactionMetadata: nil,
            users: users
        )
    }
}
