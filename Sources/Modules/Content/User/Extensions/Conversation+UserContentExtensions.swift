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
    var currentUserPenPalsSharingData: PenPalsSharingData? { metadata.penPalsSharingData.firstWithCurrentUserID }
    var currentUserSharesPenPalsDataWithAllUsers: Bool {
        guard metadata.isPenPalsConversation else { return true }
        return currentUserPenPalsSharingData?
            .sharesDataWithUserIDs?
            .containsAllStrings(in: participants.filter { $0 != currentUserParticipant }.map(\.userID)) ?? false
    }

    var isEmpty: Bool { id.key.isBlank && id.hash.isBlank }
    var isMock: Bool { id.key == CommonConstants.newConversationID }

    /// - Note: Returns `nil` if the conversation has > 2 total participants.
    var isOtherUserSharingPenPalsData: Bool? {
        guard metadata.isPenPalsConversation else { return true }
        guard participants.count == 2 else { return nil }
        guard let otherUser = users?.first else { return false }
        return userSharesPenPalsDataWithCurrentUser(otherUser)
    }

    // swiftlint:disable:next identifier_name
    var participantsSharingPenPalsDataWithCurrentUser: [Participant]? {
        guard metadata.isPenPalsConversation else { return participants }
        return metadata
            .penPalsSharingData
            .filter { $0.sharesDataWithCurrentUser == true }
            .reduce(into: [Participant]()) { partialResult, datum in
                if let participant = participants.first(where: { $0.userID == datum.userID }) {
                    partialResult.append(participant)
                }
            }
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

    func currentUserSharesPenPalsData(with user: User) -> Bool {
        guard metadata.isPenPalsConversation else { return true }
        return (currentUserPenPalsSharingData?.sharesDataWithUserIDs ?? []).contains(user.id)
    }

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

    func mutuallySharedPenPalsDataBetweenCurrentUserAnd(_ user: User) -> Bool {
        guard metadata.isPenPalsConversation else { return true }
        return currentUserSharesPenPalsData(with: user) && userSharesPenPalsDataWithCurrentUser(user)
    }

    func userSharesPenPalsDataWithCurrentUser(_ user: User) -> Bool {
        guard metadata.isPenPalsConversation else { return true }
        return (participantsSharingPenPalsDataWithCurrentUser ?? []).map(\.userID).contains(user.id)
    }
}
