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

            let addToConversationAction: AKAction = .init(
                "Add to Conversation",
                style: .preferred
            ) {
                Task { @MainActor in
                    self.navigation.navigate(to: .chat(.sheet(.none)))
                    Observables.chatInfoPageLoadingStateUpdated.trigger()

                    let addToConversationResult = await self.clientSession.activity.addToConversation(
                        user.id,
                        conversation: conversation
                    )

                    switch addToConversationResult {
                    case let .success(conversation):
                        self.clientSession.conversation.setCurrentConversation(conversation)
                        self.chatPageViewService.reloadCollectionView()
                        Observables.currentConversationActivityChanged.trigger()

                    case let .failure(exception):
                        Logger.log(exception, with: .toast)
                    }
                }
            }

            await AKActionSheet(
                message: UIApplication.v26FeaturesEnabled ? nil : user.displayName,
                actions: [addToConversationAction],
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                sourceItem: .custom(.string(
                    user.displayName.components(separatedBy: " ").last ?? user.displayName
                ))
            ).present(translating: [.actions([])])

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
}
