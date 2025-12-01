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

struct ActivitySessionService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Add User to Conversation

    func addToConversation(
        _ userID: String,
        conversation: Conversation
    ) async -> Callback<Conversation, Exception> {
        guard let activity = Activity(.addedToConversation(userID: userID)) else {
            return .failure(.init(
                "Failed to synthesize activity.",
                metadata: .init(sender: self)
            ))
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

        let updateValueResult = await conversation.updateValue(
            conversation.participants + [.init(userID: userID)],
            forKey: .participants
        )

        switch updateValueResult {
        case let .success(conversation):
            let newMetadata = conversation.metadata.copyWith(
                messageRecipientConsentAcknowledgementData: newMessageRecipientConsentAcknowledgementData,
                penPalsSharingData: newPenPalsSharingData,
            )

            let updateValueResult = await conversation.updateValue(
                newMetadata,
                forKey: .metadata
            )

            switch updateValueResult {
            case let .success(conversation):
                if let exception = await addUserToConversation(
                    userID: userID,
                    conversationID: conversation.id
                ) {
                    return .failure(exception)
                }

                return await conversation.logActivity(activity)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func addUserToConversation(
        userID: String,
        conversationID: ConversationID
    ) async -> Exception? {
        let getUserResult = await networking.userService.getUser(id: userID)

        switch getUserResult {
        case let .success(user):
            let updateValueResult = await user.updateValue(
                ((user.conversationIDs ?? []).filter { $0.key != conversationID.key } + [conversationID]).unique,
                forKey: .conversationIDs
            )

            switch updateValueResult {
            case .success: return nil
            case let .failure(exception): return exception
            }

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Remove User from Conversation

    func removeFromConversation(
        _ userID: String,
        conversation: Conversation,
        removeFromUser: Bool = true
    ) async -> Callback<Conversation, Exception> {
        guard let activity = Activity(
            userID == User.currentUserID ? .leftConversation : .removedFromConversation(userID: userID)
        ) else {
            return .failure(.init(
                "Failed to synthesize activity.",
                metadata: .init(sender: self)
            ))
        }

        let updateValueResult = await conversation.updateValue(
            conversation.participants.filter { $0.userID != userID },
            forKey: .participants
        )

        switch updateValueResult {
        case let .success(conversation):
            let newMetadata = conversation.metadata.copyWith(
                messageRecipientConsentAcknowledgementData: conversation
                    .metadata
                    .messageRecipientConsentAcknowledgementData
                    .filter { $0.userID != userID },
                penPalsSharingData: conversation
                    .metadata
                    .penPalsSharingData
                    .filter { $0.userID != userID },
                nilRequiresConsentFromInitiator: conversation
                    .metadata
                    .requiresConsentFromInitiator == userID
            )

            let updateValueResult = await conversation.updateValue(
                newMetadata,
                forKey: .metadata
            )

            switch updateValueResult {
            case let .success(conversation):
                if removeFromUser {
                    if let exception = await networking.conversationService.removeConversationFromUsers(
                        userIDs: [userID],
                        conversationIDKey: conversation.id.key
                    ) {
                        return .failure(exception)
                    }
                }

                return await conversation.logActivity(activity)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
