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

struct NewChatPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.chatPageViewService.recipientBar) private var recipientBarService: RecipientBarService?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Actions

    enum Action {
        case viewAppeared // swiftlint:disable:next identifier_name
        case animatePenPalsToolbarButtonBackgroundColor

        case doneToolbarButtonTapped
        case firstMessageSent
        case penPalsToolbarButtonTapped

        case isDoneToolbarButtonEnabledChanged(Bool)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var conversation: Conversation = .empty
        var doneToolbarButtonText = ""
        var isDoneToolbarButtonEnabled = true
        var navigationTitle = ""
        var penPalsToolbarButtonBackgroundColor: Color = .purple
        var shouldShowPenPalsToolbarButton = false
        var shouldUseBoldDoneToolbarButton = false
        var v26NavigationBarProxyViewID = UUID()

        /* MARK: Computed Properties */

        var navigationBarOpacity: CGFloat {
            @Dependency(\.uiApplication.presentedViewControllers) var viewControllers: [UIViewController]
            return (viewControllers
                .compactMap { $0 as? ChatPageViewController }
                .first?
                .messagesCollectionView
                .contentOffset
                .y ?? 0) > 0 ? 0.8 : 0
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            services.analytics.logEvent(.accessNewChatPage)

            state.doneToolbarButtonText = Localized(.cancel).wrappedValue
            state.navigationTitle = Application.isInPrevaricationMode ? "Create chat" : Localized(.newMessage).wrappedValue
            state.shouldShowPenPalsToolbarButton = clientSession.user.currentUser?.isPenPalsParticipant ?? false

            Observables.newChatPagePenPalsToolbarButtonAnimation.trigger()

        case .animatePenPalsToolbarButtonBackgroundColor:
            state.penPalsToolbarButtonBackgroundColor = .random
            Task.delayed(by: .milliseconds(750)) { Observables.newChatPagePenPalsToolbarButtonAnimation.trigger() }

        case .doneToolbarButtonTapped:
            navigation.navigate(to: .userContent(.sheet(.none)))

        case .firstMessageSent:
            guard let currentConversation = clientSession.conversation.currentConversation,
                  let cellViewData = ConversationCellViewData(currentConversation) else { return .none }

            state.doneToolbarButtonText = Localized(.done).wrappedValue
            state.navigationTitle = cellViewData.titleLabelText
            state.shouldShowPenPalsToolbarButton = false
            state.shouldUseBoldDoneToolbarButton = true

            guard UIApplication.isFullyV26Compatible else { return .none }
            state.v26NavigationBarProxyViewID = UUID()

        case let .isDoneToolbarButtonEnabledChanged(isDoneToolbarButtonEnabled):
            state.isDoneToolbarButtonEnabled = isDoneToolbarButtonEnabled

        case .penPalsToolbarButtonTapped:
            Task { @MainActor in
                let getRandomPenPalsParticipantResult = await services.penPals.getRandomPenPalsParticipant()

                switch getRandomPenPalsParticipantResult {
                case let .success(user):
                    recipientBarService?.contactSelectionUI.selectContactPair(
                        .withUser(
                            user,
                            name: user.penPalsName
                        )
                    )

                    guard recipientBarService?.layout.textField?.isFirstResponder == false else { return }
                    recipientBarService?.layout.textField?.becomeFirstResponder()

                case let .failure(exception):
                    Logger.log(
                        exception,
                        with: .toast(
                            style: exception.isEqual(to: .penPalResolutionFailed) ? .info : .error
                        )
                    )
                }
            }
        }

        return .none
    }
}
