//
//  ActivitySessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/// The service that adds and removes conversation participants, recording each change as an
/// activity.
struct ActivitySessionService {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.penPals) private var penPalsService: PenPalsService

    // MARK: - Add User to Conversation

    /// Adds the user with the given identifier to the given conversation, recording the change as
    /// an activity.
    ///
    /// In a PenPals conversation, the metadata change is applied
    /// inside a database transaction, so concurrent sharing updates
    /// from other participants are never overwritten, and if the
    /// added user is known to the current user, the current user's
    /// sharing record is updated to share their data with them.
    ///
    /// - Parameters:
    ///   - userID: The identifier of the user to add.
    ///   - conversation: The conversation to add the user to.
    ///
    /// - Throws: An `Exception` if the activity cannot be synthesized or the write fails.
    func addToConversation(
        _ userID: String,
        conversation: Conversation
    ) async throws(Exception) {
        guard let activity = Activity(.addedToConversation(userID: userID)) else {
            throw Exception(
                "Failed to synthesize activity.",
                metadata: .init(sender: self)
            )
        }

        let newActivities = ((conversation.activities ?? []) + [activity]).filter { $0 != .empty }
        let newParticipants = conversation.participants + [.init(userID: userID)]

        let updatedConversation: Conversation
        if conversation.metadata.isPenPalsConversation {
            updatedConversation = try await conversation
                .addParticipantMetadata(
                    forUserID: userID,
                    sharingCurrentUserData: penPalsService.isKnownToCurrentUser(userID)
                )
                .updateValues(
                    with: [
                        \.activities: newActivities,
                        \.participants: newParticipants,
                    ]
                )
        } else {
            // swiftlint:disable:next identifier_name
            let newMessageRecipientConsentAcknowledgementData = conversation
                .metadata
                .messageRecipientConsentAcknowledgementData + [
                    .init(
                        userID: userID,
                        consentAcknowledged: conversation.metadata.requiresConsentFromInitiator != nil ? false : true
                    ),
                ]

            updatedConversation = try await conversation.updateValues(
                with: [
                    \.activities: newActivities,
                    \.metadata: conversation.metadata.copyWith(
                        messageRecipientConsentAcknowledgementData: newMessageRecipientConsentAcknowledgementData,
                        penPalsSharingData: conversation.metadata.penPalsSharingData + [.init(userID: userID)]
                    ),
                    \.participants: newParticipants,
                ]
            )
        }

        try await addUserToConversation(
            userID: userID,
            conversationID: updatedConversation.id
        )
    }

    private func addUserToConversation(
        userID: String,
        conversationID: ConversationID
    ) async throws(Exception) {
        let path = [
            NetworkPath.users.rawValue,
            userID,
            User.SerializableKey.conversationIDs.rawValue,
            conversationID.key,
        ].joined(separator: "/")

        try await networking.database.commit([path: conversationID.hash])
        coreUtilities.clearCaches([
            .messageBackgroundColor,
        ])
    }

    // MARK: - Remove User from Conversation

    /// Removes the user with the given identifier from the given conversation, recording the change
    /// as an activity.
    ///
    /// The removed user's identifier is stripped from the remaining
    /// PenPals sharing records. In a PenPals conversation, the
    /// metadata change is applied inside a database transaction, so
    /// concurrent sharing updates from other participants are never
    /// overwritten.
    ///
    /// - Parameters:
    ///   - userID: The identifier of the user to remove.
    ///   - conversation: The conversation to remove the user from.
    ///   - removeFromUser: A Boolean value that determines whether to also remove the conversation
    ///     from the user's record.
    ///
    /// - Throws: An `Exception` if the activity cannot be synthesized or the write fails.
    func removeFromConversation(
        _ userID: String,
        conversation: Conversation,
        removeFromUser: Bool = true
    ) async throws(Exception) {
        guard let activity = Activity(
            userID == User.currentUserID ? .leftConversation : .removedFromConversation(userID: userID)
        ) else {
            throw Exception(
                "Failed to synthesize activity.",
                metadata: .init(sender: self)
            )
        }

        let newActivities = ((conversation.activities ?? []) + [activity]).filter { $0 != .empty }
        let newParticipants = conversation.participants.filter { $0.userID != userID }

        let updatedConversation: Conversation
        if conversation.metadata.isPenPalsConversation {
            updatedConversation = try await conversation
                .removeParticipantMetadata(forUserID: userID)
                .updateValues(
                    with: [
                        \.activities: newActivities,
                        \.participants: newParticipants,
                    ]
                )
        } else {
            let newMetadata = conversation.metadata.copyWith(
                name: newParticipants.count == 2 ? String.bangQualifiedEmpty : conversation.metadata.name,
                messageRecipientConsentAcknowledgementData: conversation
                    .metadata
                    .messageRecipientConsentAcknowledgementData
                    .filter { $0.userID != userID },
                penPalsSharingData: conversation
                    .metadata
                    .penPalsSharingData
                    .removingUser(withID: userID),
                nilImageData: newParticipants.count == 2,
                nilRequiresConsentFromInitiator: conversation
                    .metadata
                    .requiresConsentFromInitiator == userID
            )

            updatedConversation = try await conversation.updateValues(
                with: [
                    \.activities: newActivities,
                    \.metadata: newMetadata,
                    \.participants: newParticipants,
                ]
            )
        }

        if removeFromUser {
            try await networking.conversationService.removeConversationFromUsers(
                userIDs: [userID],
                conversationIDKey: updatedConversation.id.key
            )
        }

        coreUtilities.clearCaches([
            .messageBackgroundColor,
        ])
    }
}

private extension [PenPalsSharingData] {
    func removingUser(withID userID: String) -> [PenPalsSharingData] {
        filter { $0.userID != userID }.map { sharingData in
            let sharesDataWithUserIDs = (sharingData.sharesDataWithUserIDs ?? []).filter { $0 != userID }
            return .init(
                userID: sharingData.userID,
                sharesDataWithUserIDs: sharesDataWithUserIDs.isEmpty ? nil : sharesDataWithUserIDs
            )
        }
    }
}
