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

    @Dependency(\.commonServices.analytics) private var analyticsService: AnalyticsService
    @Dependency(\.clientSession.conversation.currentConversation) private var currentConversation: Conversation?

    // MARK: - Properties

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case doneToolbarButtonTapped
        case firstMessageSent

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

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            analyticsService.logEvent(.accessNewChatPage)

            state.doneToolbarButtonText = Localized(.cancel).wrappedValue
            state.navigationTitle = Application.isInPrevaricationMode ? "Create chat" : Localized(.newMessage).wrappedValue

        case .doneToolbarButtonTapped:
            navigationCoordinator.navigate(to: .userContent(.sheet(.none)))

        case .firstMessageSent:
            guard let currentConversation,
                  let cellViewData = ConversationCellViewData(currentConversation) else { return .none }

            state.doneToolbarButtonText = Localized(.done).wrappedValue
            state.navigationTitle = cellViewData.titleLabelText
            state.shouldUseBoldDoneToolbarButton = true

        case let .isDoneToolbarButtonEnabledChanged(isDoneToolbarButtonEnabled):
            state.isDoneToolbarButtonEnabled = isDoneToolbarButtonEnabled

        case let .isPresentingContactSelectorSheetChanged(isPresentingContactSelectorSheet):
            state.isPresentingContactSelectorSheet = isPresentingContactSelectorSheet
        }

        return .none
    }
}
