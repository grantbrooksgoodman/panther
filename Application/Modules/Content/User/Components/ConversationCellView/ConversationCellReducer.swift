//
//  ConversationCellReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct ConversationCellReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.analytics) private var analyticsService: AnalyticsService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.conversationCellViewService) private var viewService: ConversationCellViewService

    // MARK: - Properties

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case blockUsersButtonTapped
        case cellTapped
        case deleteConversationButtonTapped
        case reportUsersButtonTapped
        case userInfoBadgeTapped
    }

    // MARK: - Feedback

    public enum Feedback {
        case deleteConversationReturned(Exception?)
        case deletionActionSheetDismissed(cancelled: Bool)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // String
        @Localized(.blockUser) public var blockUsersButtonText: String
        @Localized(.delete) public var deleteConversationButtonText: String
        @Localized(.reportUser) public var reportUsersButtonText: String

        // Other
        public var cellViewData: ConversationCellViewData = .empty
        public var conversation: Conversation

        /* MARK: Computed Properties */

        public var chevronImageForegroundColor: Color {
            guard ThemeService.isDarkModeActive else {
                return .init(
                    uiColor: .titleText.lighter(by: AppConstants.CGFloats.ConversationCellView.chevronImageForegroundColorAdjustmentPercentage) ?? .titleText
                )
            }

            return .init(
                uiColor: .titleText.darker(by: AppConstants.CGFloats.ConversationCellView.chevronImageForegroundColorAdjustmentPercentage) ?? .titleText
            )
        }

        public var subtitleLabelTextForegroundColor: Color = .init(
            uiColor: .subtitleText.lighter(
                by: AppConstants.CGFloats.ConversationCellView.subtitleLabelForegroundColorAdjustmentPercentage
            ) ?? .subtitleText
        )

        /* MARK: Init */

        public init(_ conversation: Conversation) {
            self.conversation = conversation
        }
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            guard let cellViewData = ConversationCellViewData(state.conversation) else { return .none }
            state.cellViewData = cellViewData

        case .action(.blockUsersButtonTapped):
            guard let users = state.conversation.users else { return .none }
            return .fireAndForget {
                guard let exception = await viewService.blockUsersButtonTapped(users) else { return }
                Logger.log(exception)
            }

        case .action(.cellTapped):
            navigationCoordinator.navigate(to: .userContent(.push(.chat(state.conversation))))

        case .action(.deleteConversationButtonTapped):
            let title = state.cellViewData.titleLabelText
            return .task {
                let result = await viewService.presentDeletionActionSheet(title)
                return .deletionActionSheetDismissed(cancelled: result)
            }

        case .action(.reportUsersButtonTapped):
            guard let users = state.conversation.users else { return .none }
            return .fireAndForget {
                guard let exception = await viewService.reportUsersButtonTapped(users) else { return }
                Logger.log(exception)
            }

        case .action(.userInfoBadgeTapped):
            viewService.presentUserInfoAlert(state.cellViewData)

        case let .feedback(.deleteConversationReturned(exception)):
            defer { clientSession.user.startObservingCurrentUserChanges() }

            guard let exception else {
                analyticsService.logEvent(.deleteConversation)
                return .none
            }

            Logger.log(exception, with: .toast())

        case let .feedback(.deletionActionSheetDismissed(cancelled: cancelled)):
            guard !cancelled else { return .none }

            clientSession.user.stopObservingCurrentUserChanges()
            let conversation = state.conversation
            return .task {
                let result = await clientSession.conversation.deleteConversation(conversation)
                return .deleteConversationReturned(result)
            }
        }

        return .none
    }
}
