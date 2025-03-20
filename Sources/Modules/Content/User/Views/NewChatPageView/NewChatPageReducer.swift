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

public struct NewChatPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.clientSession.conversation.currentConversation) private var currentConversation: Conversation?
    @Dependency(\.navigation) private var navigation: NavigationCoordinator<RootNavigationService> // swiftlint:disable:next line_length
    @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI) private var recipientBarContactSelectionUIService: RecipientBarContactSelectionUIService?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Actions

    public enum Action {
        case viewAppeared // swiftlint:disable:next identifier_name
        case animatePenPalsToolbarButtonBackgroundColor

        case doneToolbarButtonTapped
        case firstMessageSent
        case penPalsToolbarButtonTapped

        case isDoneToolbarButtonEnabledChanged(Bool)
        case isPresentingContactSelectorSheetChanged(Bool)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isDoneToolbarButtonEnabled = true
        public var isPresentingContactSelectorSheet = false
        public var shouldUseBoldDoneToolbarButton = false

        // String
        public var doneToolbarButtonText = ""
        public var navigationTitle = ""

        // Other
        public var conversation: Conversation = .empty
        public var penPalsToolbarButtonBackgroundColor: Color = .purple

        /* MARK: Computed Properties */

        public var shouldShowPenPalsToolbarButton: Bool {
            @Dependency(\.clientSession.user.currentUser) var currentUser: User?
            return currentUser?.isPenPalsParticipant ?? false
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            services.analytics.logEvent(.accessNewChatPage)

            state.doneToolbarButtonText = Localized(.cancel).wrappedValue
            state.navigationTitle = Application.isInPrevaricationMode ? "Create chat" : Localized(.newMessage).wrappedValue

            Observables.newChatPagePenPalsToolbarButtonAnimation.trigger()

        case .animatePenPalsToolbarButtonBackgroundColor:
            state.penPalsToolbarButtonBackgroundColor = .random
            Task.delayed(by: .milliseconds(750)) { Observables.newChatPagePenPalsToolbarButtonAnimation.trigger() }

        case .doneToolbarButtonTapped:
            navigation.navigate(to: .userContent(.sheet(.none)))

        case .firstMessageSent:
            guard let currentConversation,
                  let cellViewData = ConversationCellViewData(currentConversation) else { return .none }

            state.doneToolbarButtonText = Localized(.done).wrappedValue
            state.navigationTitle = cellViewData.titleLabelText
            state.shouldUseBoldDoneToolbarButton = true

        case .penPalsToolbarButtonTapped:
            Task { @MainActor in
                let getRandomPenPalsParticipantResult = await services.penPals.getRandomPenPalsParticipant()

                switch getRandomPenPalsParticipantResult {
                case let .success(user):
                    recipientBarContactSelectionUIService?.selectContactPair(
                        .withUser(
                            user,
                            name: user.penPalsName
                        )
                    )

                case let .failure(exception):
                    Logger.log(
                        exception,
                        with: .toast(style: exception.isEqual(to: .penPalResolutionFailed) ? .info : .error)
                    )
                }
            }

        case let .isDoneToolbarButtonEnabledChanged(isDoneToolbarButtonEnabled):
            state.isDoneToolbarButtonEnabled = isDoneToolbarButtonEnabled

        case let .isPresentingContactSelectorSheetChanged(isPresentingContactSelectorSheet):
            state.isPresentingContactSelectorSheet = isPresentingContactSelectorSheet
        }

        return .none
    }
}
