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

    var currentUserGrantedMessageReceiptConsent: Bool {
        guard !currentUserInitiatorRequiresMessageReceiptConsent,
              metadata.requiresConsentFromInitiator != nil else { return true }
        return metadata
            .messageRecipientConsentAcknowledgementData
            .firstWithCurrentUserID?
            .consentAcknowledged == true
    }

    // swiftlint:disable:next identifier_name
    var currentUserInitiatorRequiresMessageReceiptConsent: Bool { metadata.requiresConsentFromInitiator == User.currentUserID }
    var currentUserParticipant: Participant? { participants.firstWithCurrentUserID }
    var currentUserPenPalsSharingData: PenPalsSharingData? { metadata.penPalsSharingData.firstWithCurrentUserID }
    var currentUserSharesPenPalsDataWithAllUsers: Bool {
        guard metadata.isPenPalsConversation else { return true }
        return currentUserPenPalsSharingData?
            .sharesDataWithUserIDs?
            .containsAllStrings(in: participants.filter { $0 != currentUserParticipant }.map(\.userID)) ?? false
    }

    var didSendConsentMessage: Bool {
        messages?.contains(where: \.isConsentRequestMessage) == true
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

    var isVisibleForCurrentUser: Bool {
        @Dependency(\.clientSession.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
        guard let currentUserParticipant,
              !currentUserParticipant.hasDeletedConversation,
              !(blockedUserIDs ?? []).containsAnyString(in: participants.map(\.userID)) else { return false }
        return true
    }

    var mediaItemMetadata: [MediaItemView.Metadata] {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?

        var users = users ?? []
        if let currentUser { users += [currentUser] }
        let messages = (messages?.filter { $0.richContent?.mediaComponent != nil } ?? []).sortedByDescendingSentDate

        var mediaMetadata = [MediaItemView.Metadata]()
        for mediaMessage in messages {
            guard let mediaFile = mediaMessage.richContent?.mediaComponent,
                  let user = users.first(where: { $0.id == mediaMessage.fromAccountID }) else { continue }

            var senderLabelText = Localized(.fromYou).wrappedValue.firstLowercase
            if user.id != User.currentUserID {
                senderLabelText = Localized(.fromUser).wrappedValue.replacingOccurrences(
                    of: "⌘",
                    with: user.displayName
                )
            }

            var mediaTypeLabelText = Localized(.attachment).wrappedValue
            if mediaFile.fileExtension.isDocument {
                mediaTypeLabelText = Localized(.document).wrappedValue
            } else if mediaFile.fileExtension.isImage {
                mediaTypeLabelText = Localized(.image).wrappedValue
            } else if mediaFile.fileExtension.isVideo {
                mediaTypeLabelText = Localized(.video).wrappedValue
            }

            mediaMetadata.append(
                .init(
                    mediaFile,
                    mediaTypeLabelText: mediaTypeLabelText,
                    senderLabelText: senderLabelText,
                    timestampLabelText: mediaMessage.sentDate.formattedShortString
                )
            )
        }

        return mediaMetadata
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
