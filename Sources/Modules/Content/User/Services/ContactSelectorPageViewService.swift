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

/// The service that handles the contact selector page's user interactions.
///
/// Use ``ContactSelectorPageViewService`` to respond to selections on the contact selector
/// page, which is presented as a sheet either from the chat info page – to add a participant
/// to the conversation – or from the new chat page – to choose a recipient.
struct ContactSelectorPageViewService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.commonServices.invite) private var inviteService: InviteService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    @SharedEvent(\.chatInfoPageLoadingStateUpdated) private var chatInfoPageLoadingStateUpdated
    @SharedEvent(\.currentConversationActivityChanged) private var currentConversationActivityChanged

    // MARK: - Reducer Action Handlers

    /// Dismisses the contact selector sheet without a selection.
    ///
    /// When entered from the new chat page, the input bar's appearance is restored and the
    /// contact selection UI's label representation is updated to match the recipient bar's
    /// focus.
    ///
    /// - Parameter entryPoint: The page from which the contact selector was presented.
    @MainActor
    func cancelToolbarButtonTapped(from entryPoint: ContactSelectorPageView.EntryPoint) {
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

    /// Returns the registered user with the given phone number.
    ///
    /// - Parameter phoneNumber: The phone number to look up.
    ///
    /// - Returns: The matching user.
    ///
    /// - Throws: An `Exception` if no registered user matches, or if the lookup fails.
    func findUser(with phoneNumber: PhoneNumber) async throws(Exception) -> User {
        try await networking.userService.getUser(
            phoneNumber: phoneNumber
        )
    }

    /// Presents the invitation prompt, surfacing any error as a toast.
    func inviteToolbarButtonTapped() {
        Task { @MainActor in
            do throws(Exception) {
                try await inviteService.presentInvitationPrompt()
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    /// Presents an alert offering to invite the given phone number's owner to the app.
    ///
    /// If the user accepts, the invitation prompt is presented.
    ///
    /// - Parameter phoneNumber: The phone number for which no registered user was found.
    func presentInvitationPrompt(phoneNumber: PhoneNumber) async {
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

    /// Responds to the user selecting a contact pair on the contact selector page.
    ///
    /// When entered from the chat info page, an action sheet offers to add the selected user
    /// to the current conversation – users already participating are ignored; adding one
    /// reloads the chat and notifies observers of the activity change. When entered from the
    /// new chat page, the sheet is dismissed and the selection is applied to the recipient
    /// bar.
    ///
    /// - Parameters:
    ///   - selectedContactPair: The contact pair the user selected.
    ///   - entryPoint: The page from which the contact selector was presented.
    @MainActor
    func selectedContactPairChanged(
        _ selectedContactPair: ContactPair,
        from entryPoint: ContactSelectorPageView.EntryPoint
    ) async {
        switch entryPoint {
        case .chatInfoPageView:
            guard let user = selectedContactPair.users.first,
                  let userID = selectedContactPair.userIDs.first,
                  let conversation = entitySession.conversation.currentConversation,
                  !conversation.participants.map(\.userID).contains(userID) else { return }

            let addToConversationAction: AKAction = .init(
                "Add to Conversation",
                style: .preferred
            ) {
                Task { @MainActor in
                    navigation.navigate(to: .chat(.sheet(.none)))
                    chatInfoPageLoadingStateUpdated.send()

                    do throws(Exception) {
                        try await entitySession.activity.addToConversation(
                            userID,
                            conversation: conversation
                        )

                        chatPageViewService.reloadCollectionView()
                        currentConversationActivityChanged.send()
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            var sourceItemString = user.displayName
            let components = user.displayName.components(separatedBy: " ")
            if let lastComponent = components.last,
               components.count > 1,
               sourceItemString != user.phoneNumber.formattedString() {
                sourceItemString = lastComponent
            }

            await AKActionSheet(
                message: UIApplication.isFullyV26Compatible ? nil : user.displayName,
                actions: [addToConversationAction],
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                sourceItem: .custom(.string(sourceItemString))
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
