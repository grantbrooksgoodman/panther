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

    // MARK: - Properties

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case doneToolbarButtonTapped
        case isPresentingContactSelectorSheetChanged(Bool)
    }

    // MARK: - Feedback

    public enum Feedback {}

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isPresentingContactSelectorSheet = false

        // String
        @Localized(.cancel) public var doneToolbarButtonText: String
        @Localized(.newMessage) public var navigationTitle: String

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
            NavigationBar.setAppearance(.themed(showsDivider: false))

        case .action(.doneToolbarButtonTapped):
            navigationCoordinator.navigate(to: .userContent(.sheet(.none)))

        case let .action(.isPresentingContactSelectorSheetChanged(isPresentingContactSelectorSheet)):
            state.isPresentingContactSelectorSheet = isPresentingContactSelectorSheet
        }

        return .none
    }
}
