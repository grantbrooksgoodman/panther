//
//  NewChatPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

/// The reducer that drives the new chat page.
///
/// This page composes a new conversation. The user chooses recipients through the recipient bar,
/// and – when eligible – can add a random PenPals participant with the PenPals toolbar button.
///
/// The page's behavior contract:
///
/// - On appearance, the page configures its toolbar – titling it, labeling the done button as
///   Cancel, and showing the PenPals button when the current user is a PenPals participant – and
///   begins animating the PenPals button.
/// - Tapping the PenPals button adds a random PenPals participant as a recipient.
/// - Once the first message is sent, the toolbar updates to reflect the now-created conversation:
///   its title becomes the conversation's title, the PenPals button is hidden, and the done
///   button is relabeled.
/// - Tapping done dismisses the page.
struct NewChatPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.chatPageViewService.recipientBar) private var recipientBarService: RecipientBarService?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    @SharedEvent(\.newChatPagePenPalsToolbarButtonAnimation) private var newChatPagePenPalsToolbarButtonAnimation

    // MARK: - Actions

    /// The actions the new chat page can process.
    enum Action {
        /// An action that indicates the view appeared. Configures the toolbar and begins
        /// animating the PenPals button.
        case viewAppeared

        /// An action that advances the PenPals button's color animation.
        case animatePenPalsToolbarButtonBackgroundColor // swiftlint:disable:this identifier_name

        /// An action that indicates the user tapped the done button. Dismisses the page.
        case doneToolbarButtonTapped

        /// An action that indicates the first message was sent. Updates the toolbar to reflect
        /// the now-created conversation.
        case firstMessageSent

        /// An action that indicates the user tapped the PenPals button. Selects a random PenPals
        /// participant as a recipient.
        case penPalsToolbarButtonTapped

        /// An action that indicates selecting a random PenPals participant failed, carrying the
        /// resulting `Exception`.
        case getRandomPenPalsParticipantFailed(Exception)

        /// An action that indicates a random PenPals participant was selected, carrying the
        /// participant. Adds them as a recipient.
        case getRandomPenPalsParticipantReturned(User)

        /// An action that indicates whether the done button is enabled changed, carrying the new
        /// value.
        case isDoneToolbarButtonEnabledChanged(Bool)
    }

    // MARK: - State

    /// The state of the new chat page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The conversation being composed.
        var conversation: Conversation = .empty

        /// The text the done button displays.
        var doneToolbarButtonText = ""

        /// A Boolean value that indicates whether the done button is enabled.
        var isDoneToolbarButtonEnabled = true

        /// The page's navigation title.
        var navigationTitle = ""

        /// The background color of the PenPals button, animated while the button is shown.
        var penPalsToolbarButtonBackgroundColor: Color = .purple

        /// A Boolean value that indicates whether the PenPals button is shown. Shown when the
        /// current user is a PenPals participant.
        var shouldShowPenPalsToolbarButton = false

        /// A Boolean value that indicates whether the done button uses a bold font.
        var shouldUseBoldDoneToolbarButton = false

        /// The identity of the navigation bar proxy. Regenerated to rebuild it once the first
        /// message is sent.
        var v26NavigationBarProxyViewID = UUID()

        /* MARK: Computed Properties */

        /// The navigation bar's opacity. Partially opaque once the message list has scrolled;
        /// otherwise, transparent.
        @MainActor
        var navigationBarOpacity: CGFloat {
            @Dependency(\.uiApplication.presentedViewControllers) var viewControllers: [UIViewController]
            return (
                viewControllers
                    .compactMap { $0 as? ChatPageViewController }
                    .first?
                    .messagesCollectionView
                    .contentOffset
                    .y ?? 0
            ) > 0 ? 0.8 : 0
        }
    }

    // MARK: - Reduce

    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            services.analytics.logEvent(.accessNewChatPage)

            state.doneToolbarButtonText = Localized(.cancel).wrappedValue
            state.navigationTitle = Application.isInPrevaricationMode ? "Create chat" : Localized(.newMessage).wrappedValue
            state.shouldShowPenPalsToolbarButton = entitySession.user.currentUser?.isPenPalsParticipant ?? false

            newChatPagePenPalsToolbarButtonAnimation.send()

        case .animatePenPalsToolbarButtonBackgroundColor:
            state.penPalsToolbarButtonBackgroundColor = .random
            Task.delayed(by: .milliseconds(750)) {
                await newChatPagePenPalsToolbarButtonAnimation.send()
            }

        case .doneToolbarButtonTapped:
            navigation.navigate(to: .userContent(.sheet(.none)))

        case .firstMessageSent:
            guard let currentConversation = entitySession.conversation.currentConversation,
                  let cellViewData = ConversationCellViewData(
                      currentConversation
                  ) else { return .none }

            state.doneToolbarButtonText = Localized(.done).wrappedValue
            state.navigationTitle = cellViewData.titleLabelText
            state.shouldShowPenPalsToolbarButton = false
            state.shouldUseBoldDoneToolbarButton = true

            guard UIApplication.isFullyV26Compatible else { return .none }
            state.v26NavigationBarProxyViewID = UUID()

        case let .getRandomPenPalsParticipantFailed(exception):
            Logger.log(
                exception,
                with: .toast(
                    style: exception.isEqual(to: .penPalResolutionFailed) ? .info : .error
                )
            )

        case let .getRandomPenPalsParticipantReturned(user):
            recipientBarService?.contactSelectionUI.selectContactPair(
                .withUser(
                    user,
                    name: user.penPalsName
                )
            )

            guard recipientBarService?
                .layout
                .textField?
                .isFirstResponder == false else { return .none }

            recipientBarService?
                .layout
                .textField?
                .becomeFirstResponder()

        case let .isDoneToolbarButtonEnabledChanged(isDoneToolbarButtonEnabled):
            state.isDoneToolbarButtonEnabled = isDoneToolbarButtonEnabled

        case .penPalsToolbarButtonTapped:
            return .task { @MainActor in
                do throws(Exception) {
                    return try await .getRandomPenPalsParticipantReturned(
                        services.penPals.getRandomPenPalsParticipant()
                    )
                } catch {
                    return .getRandomPenPalsParticipantFailed(error)
                }
            }
        }

        return .none
    }
}
