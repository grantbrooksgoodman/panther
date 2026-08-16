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

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Add User to Conversation

    /// Adds the user with the given identifier to the given conversation, recording the change as
    /// an activity.
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

        // swiftlint:disable:next identifier_name
        let newMessageRecipientConsentAcknowledgementData = conversation
            .metadata
            .messageRecipientConsentAcknowledgementData + [
                .init(
                    userID: userID,
                    consentAcknowledged: conversation.metadata.requiresConsentFromInitiator != nil ? false : true
                ),
            ]

        let newPenPalsSharingData = conversation
            .metadata
            .penPalsSharingData + [.init(userID: userID)]

        let newMetadata = conversation.metadata.copyWith(
            messageRecipientConsentAcknowledgementData: newMessageRecipientConsentAcknowledgementData,
            penPalsSharingData: newPenPalsSharingData
        )

        let newActivities = ((conversation.activities ?? []) + [activity]).filter { $0 != .empty }
        let newParticipants = conversation.participants + [.init(userID: userID)]

        let updatedConversation = try await conversation.updateValues(
            with: [
                \.activities: newActivities,
                \.metadata: newMetadata,
                \.participants: newParticipants,
            ]
        )

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
    }

    // MARK: - Remove User from Conversation

    /// Removes the user with the given identifier from the given conversation, recording the change
    /// as an activity.
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
        let newMetadata = conversation.metadata.copyWith(
            name: newParticipants.count == 2 ? nil : conversation.metadata.name,
            messageRecipientConsentAcknowledgementData: conversation
                .metadata
                .messageRecipientConsentAcknowledgementData
                .filter { $0.userID != userID },
            penPalsSharingData: conversation
                .metadata
                .penPalsSharingData
                .filter { $0.userID != userID },
            nilImageData: newParticipants.count == 2,
            nilRequiresConsentFromInitiator: conversation
                .metadata
                .requiresConsentFromInitiator == userID
        )

        let updatedConversation = try await conversation.updateValues(
            with: [
                \.activities: newActivities,
                \.metadata: newMetadata,
                \.participants: newParticipants,
            ]
        )

        if removeFromUser {
            try await networking.conversationService.removeConversationFromUsers(
                userIDs: [userID],
                conversationIDKey: updatedConversation.id.key
            )
        }
    }
}
