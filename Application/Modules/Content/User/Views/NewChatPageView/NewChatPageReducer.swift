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
    @Dependency(\.commonServices.analytics) private var analyticsService: AnalyticsService

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

    // MARK: - Feedback

    public enum Feedback {}

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

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            analyticsService.logEvent(.accessNewChatPage)

            state.doneToolbarButtonText = Localized(.cancel).wrappedValue
            state.navigationTitle = Localized(.newMessage).wrappedValue
            NavigationBar.setAppearance(.themed(showsDivider: false))

        case .action(.doneToolbarButtonTapped):
            navigationCoordinator.navigate(to: .userContent(.sheet(.none)))

        case .action(.firstMessageSent):
            guard let currentConversation,
                  let cellViewData = ConversationCellViewData(currentConversation) else { return .none }

            state.doneToolbarButtonText = Localized(.done).wrappedValue
            state.navigationTitle = cellViewData.titleLabelText
            state.shouldUseBoldDoneToolbarButton = true

        case let .action(.isDoneToolbarButtonEnabledChanged(isDoneToolbarButtonEnabled)):
            state.isDoneToolbarButtonEnabled = isDoneToolbarButtonEnabled

        case let .action(.isPresentingContactSelectorSheetChanged(isPresentingContactSelectorSheet)):
            state.isPresentingContactSelectorSheet = isPresentingContactSelectorSheet
        }

        return .none
    }
}
