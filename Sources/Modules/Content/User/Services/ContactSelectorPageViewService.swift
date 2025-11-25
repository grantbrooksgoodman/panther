//
//  ContactSelectorPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

public struct ContactSelectorPageViewService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.commonServices.invite) private var inviteService: InviteService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Reducer Action Handlers

    public func cancelToolbarButtonTapped(from entryPoint: ContactSelectorPageView.EntryPoint) {
        navigation.navigate(to: .chat(.sheet(.none)))

        guard entryPoint == .newChatPageView else { return }
        Task.delayed(by: .milliseconds(100)) { @MainActor in
            chatPageViewService.inputBar?.forceAppearance()

            Task.delayed(by: .milliseconds(200)) { @MainActor in
                guard let recipientBarIsFirstResponder = chatPageViewService
                    .recipientBar?
                    .layout
                    .textField?
                    .isFirstResponder else { return }

                chatPageViewService
                    .recipientBar?
                    .contactSelectionUI
                    .toggleLabelRepresentation(on: !recipientBarIsFirstResponder)
            }
        }
    }

    /// `.searchQuerySubmitted`
    public func findUser(with phoneNumber: PhoneNumber) async -> Callback<User, Exception> {
        await networking.userService.getUser(phoneNumber: phoneNumber)
    }

    public func inviteToolbarButtonTapped() {
        Task { @MainActor in
            if let exception = await inviteService.presentInvitationPrompt() {
                Logger.log(exception, with: .toast)
            }
        }
    }

    /// `.findUserReturned(.failure)`
    public func presentInvitationPrompt(phoneNumber: PhoneNumber) async {
        let inviteAction = AKAction("Send Invite", style: .preferred) { inviteToolbarButtonTapped() }
        await AKAlert(
            title: phoneNumber.formattedString(),
            message: "Seems like there aren't any registered users with that phone number.\n\nWould you like to invite them to sign up?",
            actions: [inviteAction, .cancelAction]
        ).present(translating: [
            .actions([inviteAction]),
            .message,
        ])
    }

    @MainActor
    public func selectedContactPairChanged(
        _ selectedContactPair: ContactPair,
        from entryPoint: ContactSelectorPageView.EntryPoint
    ) async {
        switch entryPoint {
        case .chatInfoPageView:
            guard let user = selectedContactPair.users.first,
                  let conversation = clientSession.conversation.fullConversation,
                  !conversation.participants.map(\.userID).contains(user.id) else { return }

            guard await AKConfirmationAlert(
                message: user.displayName,
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                confirmButtonTitle: "Add to Conversation"
            ).present(translating: [.confirmButtonTitle]) else { return }

            navigation.navigate(to: .chat(.sheet(.none)))
            Observables.chatInfoPageLoadingStateUpdated.trigger()

            let addToConversationResult = await addToConversation(
                user.id,
                conversation: conversation
            )

            switch addToConversationResult {
            case let .success(conversation):
                clientSession.conversation.setCurrentConversation(conversation)
                chatPageViewService.reloadCollectionView()
                Observables.currentConversationActivityChanged.trigger()

            case let .failure(exception):
                Logger.log(exception, with: .toast)
            }

        case .newChatPageView:
            navigation.navigate(to: .chat(.sheet(.none)))

            try? await Task.sleep(for: .milliseconds(100))
            chatPageViewService.recipientBar?.contactSelectionUI.selectContactPair(
                selectedContactPair,
                performInputBarFix: true
            )

            try? await Task.sleep(for: .milliseconds(200))
            guard let recipientBarIsFirstResponder = chatPageViewService
                .recipientBar?
                .layout
                .textField?
                .isFirstResponder else { return }

            chatPageViewService
                .recipientBar?
                .contactSelectionUI
                .toggleLabelRepresentation(on: !recipientBarIsFirstResponder)
        }
    }

    // MARK: - Auxiliary

    // TODO: Consolidate this into a method on Conversation.
    private func addToConversation(
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
}
