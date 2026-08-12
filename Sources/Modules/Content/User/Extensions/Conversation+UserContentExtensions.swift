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

extension Conversation {
    // MARK: - Properties

    /// The text shown in the chat page header, or `nil` when the conversation has a name or two
    /// or fewer participants.
    ///
    /// For an unnamed group conversation, this is the number of other participants followed by a
    /// localized label.
    var chatPageHeaderLabelText: String? {
        guard metadata.name.isBangQualifiedEmpty,
              participants.count > 2 else { return nil }
        return "\(participants.count - 1) \(Localized(.people).wrappedValue)"
    }

    /// A Boolean value that indicates whether the current user has granted the message receipt
    /// consent this conversation requires. `true` when no consent is required.
    var currentUserGrantedMessageReceiptConsent: Bool {
        guard !currentUserInitiatorRequiresMessageReceiptConsent,
              metadata.requiresConsentFromInitiator != nil else { return true }
        return metadata
            .messageRecipientConsentAcknowledgementData
            .firstWithCurrentUserID?
            .consentAcknowledged == true
    }

    // swiftlint:disable identifier_name
    /// A Boolean value that indicates whether the current user is the initiator whose message
    /// receipt consent this conversation requires.
    var currentUserInitiatorRequiresMessageReceiptConsent: Bool {
        metadata.requiresConsentFromInitiator == User.currentUserID
    } // swiftlint:enable identifier_name

    /// The participant representing the current user, if any.
    var currentUserParticipant: Participant? {
        participants.firstWithCurrentUserID
    }

    /// The current user's PenPals data-sharing record for this conversation, if any.
    var currentUserPenPalsSharingData: PenPalsSharingData? {
        metadata.penPalsSharingData.firstWithCurrentUserID
    }

    /// A Boolean value that indicates whether the current user shares their PenPals data with
    /// every other participant. `true` when the conversation is not a PenPals conversation.
    var currentUserSharesPenPalsDataWithAllUsers: Bool {
        guard metadata.isPenPalsConversation else { return true }
        return currentUserPenPalsSharingData?
            .sharesDataWithUserIDs?
            .containsAllStrings(in: participants.filter { $0 != currentUserParticipant }.map(\.userID)) ?? false
    }

    /// A Boolean value that indicates whether a message receipt consent request has been sent in
    /// this conversation.
    var didSendConsentMessage: Bool {
        messages?.contains(where: \.isConsentRequestMessage) == true
    }

    /// A copy of the conversation with its system messages removed.
    var filteringSystemMessages: Conversation {
        let messageIDs = messageIDs.filter { $0.hasPrefix("-") }
        return copying(
            messageIDs: messageIDs.isEmpty ? .bangQualifiedEmpty : messageIDs
        )
    }

    /// A Boolean value that indicates whether the conversation is empty – having neither a key
    /// nor a hash.
    var isEmpty: Bool {
        id.key.isBlank && id.hash.isBlank
    }

    /// A Boolean value that indicates whether the conversation is a mock, representing a new
    /// conversation not yet created on the server.
    var isMock: Bool {
        id.key == CommonConstants.newConversationID
    }

    /// A Boolean value that indicates whether the conversation is visible to the current user.
    ///
    /// A conversation is hidden when the current user has deleted it, or when any participant is
    /// blocked.
    var isVisibleForCurrentUser: Bool {
        @Dependency(\.clientSession.entity.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
        guard let currentUserParticipant,
              !currentUserParticipant.hasDeletedConversation,
              !(blockedUserIDs ?? []).containsAnyString(in: participants.map(\.userID)) else { return false }
        return true
    }

    /// The metadata for the conversation's shared media, one entry per media message, sorted from
    /// newest to oldest.
    @MainActor
    var mediaItemMetadata: [MediaItemView.Metadata] {
        @Dependency(\.clientSession) var clientSession: ClientSession

        var users = users ?? []
        if let currentUser = clientSession.entity.user.currentUser {
            users += [currentUser]
        }

        let messages = (messages?.filter { $0.richContent?.mediaComponent != nil } ?? []).sortedByDescendingSentDate

        var mediaMetadata = [MediaItemView.Metadata]()
        for mediaMessage in messages {
            guard let mediaFile = mediaMessage.richContent?.mediaComponent,
                  let user = users
                  .first(where: {
                      $0.id == mediaMessage.fromAccountID
                  }) ?? clientSession.store.users[mediaMessage.fromAccountID] else { continue }

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

    // swiftlint:disable identifier_name
    /// The participants who share their PenPals data with the current user, or all participants
    /// when the conversation is not a PenPals conversation.
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
    } // swiftlint:enable identifier_name

    // swiftlint:disable identifier_name
    /// A copy of the conversation whose messages are limited to those sent after the current user
    /// joined it, always including consent messages.
    var withMessagesOffsetFromCurrentUserAdditionDate: Conversation {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        guard let currentUserAddedActivity = activities?
            .last(where: \.action.isCurrentUserAdded) else { return self }
        let filteredIDs = messageIDs.filter { id in
            guard let message = sessionStore.messages[id] else { return true }
            return message.isConsentMessage || message.sentDate >= currentUserAddedActivity.date
        }
        return copying(messageIDs: filteredIDs)
    } // swiftlint:enable identifier_name

    /// A copy of the conversation with its messages sorted from oldest to newest.
    var withMessagesSortedByAscendingSentDate: Conversation {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        let sortedIDs = messageIDs.sorted { first, second in
            guard let firstMessage = sessionStore.messages[first],
                  let secondMessage = sessionStore.messages[second] else { return false }
            return firstMessage.sentDate < secondMessage.sentDate
        }
        return copying(messageIDs: sortedIDs)
    }

    // MARK: - Methods

    /// Creates an empty conversation with the given users as its participants.
    ///
    /// - Parameter users: The users to include as participants.
    ///
    /// - Returns: An empty conversation containing the given users.
    static func empty(withUsers users: [User]) -> Conversation {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        // Stores users so the conversation's computed properties can resolve them.
        sessionStore.upsertUsers(Set(users))
        return .init(
            .init(key: "", hash: ""),
            activities: nil,
            messageIDs: [],
            metadata: .empty(userIDs: users.map(\.id)),
            participants: users.map {
                .init(
                    userID: $0.id,
                    hasDeletedConversation: false,
                    isTyping: false
                )
            },
            reactionMetadata: nil
        )
    }

    /// Creates a mock conversation with the given users as its participants.
    ///
    /// Use a mock conversation to represent a new conversation before it is created on the
    /// server.
    ///
    /// - Parameter users: The users to include as participants.
    ///
    /// - Returns: A mock conversation containing the given users.
    static func mock(withUsers users: [User]) -> Conversation {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        // Stores users so the conversation's computed properties can resolve them.
        sessionStore.upsertUsers(Set(users))
        return .init(
            .init(key: CommonConstants.newConversationID, hash: ""),
            activities: nil,
            messageIDs: [],
            metadata: .empty(userIDs: users.map(\.id)),
            participants: users.map { .init(userID: $0.id) },
            reactionMetadata: nil
        )
    }

    /// Returns a Boolean value that indicates whether the current user shares their PenPals data
    /// with the given user.
    ///
    /// Always `true` when the conversation is not a PenPals conversation.
    ///
    /// - Parameter user: The user to query.
    ///
    /// - Returns: `true` if the current user shares their PenPals data with the given user;
    ///   otherwise, `false`.
    func currentUserSharesPenPalsData(with user: User) -> Bool {
        guard metadata.isPenPalsConversation else { return true }
        return (currentUserPenPalsSharingData?.sharesDataWithUserIDs ?? []).contains(user.id)
    }

    /// Invalidates the conversation's local hash to force a re-fetch on the next sync cycle.
    ///
    /// This method replaces the conversation's hash with a randomly generated value and upserts
    /// the modified copy into the session store. Because the local hash no longer matches the
    /// server hash, the sync system treats the conversation as out-of-date and resolves it from
    /// the server on its next pass.
    ///
    /// No remote write is performed – the change is purely local.
    func markStaleLocally() {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        // Local hash/messageID modification to force re-fetch; no remote write.
        sessionStore.upsertConversation(
            copying(
                id: .init(
                    key: id.key,
                    hash: .init(Int.random(in: 1 ... 1_000_000)).encodedHash
                )
            )
        )
    }

    /// Returns a Boolean value that indicates whether the current user and the given user share
    /// their PenPals data with each other.
    ///
    /// Always `true` when the conversation is not a PenPals conversation.
    ///
    /// - Parameter user: The user to query.
    ///
    /// - Returns: `true` if both users share their PenPals data with each other; otherwise,
    ///   `false`.
    func mutuallySharedPenPalsDataBetweenCurrentUserAnd(_ user: User) -> Bool {
        guard metadata.isPenPalsConversation else { return true }
        return currentUserSharesPenPalsData(with: user) && userSharesPenPalsDataWithCurrentUser(user)
    }

    /// Returns a Boolean value that indicates whether the given user shares their PenPals data
    /// with the current user.
    ///
    /// Always `true` when the conversation is not a PenPals conversation or the given user is not
    /// a participant.
    ///
    /// - Parameter user: The user to query.
    ///
    /// - Returns: `true` if the given user shares their PenPals data with the current user;
    ///   otherwise, `false`.
    func userSharesPenPalsDataWithCurrentUser(_ user: User) -> Bool {
        guard metadata.isPenPalsConversation,
              participants.map(\.userID).contains(user.id) else { return true }
        return (participantsSharingPenPalsDataWithCurrentUser ?? []).map(\.userID).contains(user.id)
    }
}
