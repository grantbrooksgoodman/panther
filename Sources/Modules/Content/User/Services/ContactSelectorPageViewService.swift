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

        switch entryPoint {
        case .chatInfoPageView:
            break

        case .newChatPageView:
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
    }

    public func inviteToolbarButtonTapped() {
        Task { @MainActor in
            if let exception = await inviteService.presentInvitationPrompt() {
                Logger.log(exception, with: .toast)
            }
        }
    }

    @MainActor
    public func selectedContactPairChanged(
        _ selectedContactPair: ContactPair,
        from entryPoint: ContactSelectorPageView.EntryPoint
    ) async {
        switch entryPoint {
        case .chatInfoPageView:
            guard let user = selectedContactPair.users.first,
                  let conversation = clientSession.conversation.fullConversation else { return }

            guard !conversation.participants.map(\.userID).contains(user.id) else {
                return Toast.show(
                    .init(
                        .banner(style: .error),
                        message: "⌘\(user.displayName)⌘ is already in this conversation.",
                        perpetuation: .ephemeral(.seconds(5))
                    ),
                    translating: [.message]
                )
            }

            guard await AKConfirmationAlert(
                message: "Add ⌘\(user.displayName)⌘ to conversation?",
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [
                .confirmButtonTitle,
                .message,
            ]) else { return }

            navigation.navigate(to: .chat(.sheet(.none)))
            RootSheets.dismiss()

            let addToConversationResult = await addToConversation(
                user.id,
                conversation: conversation
            )

            switch addToConversationResult {
            case let .success(conversation):
                clientSession.conversation.setCurrentConversation(conversation)
                coreUtilities.clearCaches([.chatInfoPageViewService])
                RootSheets.present(.chatInfoPageView)

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

            return await conversation.updateValue(
                newMetadata,
                forKey: .metadata
            )

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
