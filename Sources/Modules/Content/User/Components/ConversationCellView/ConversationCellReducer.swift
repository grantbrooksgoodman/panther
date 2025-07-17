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
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.conversationCellViewService) private var viewService: ConversationCellViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case blockUsersButtonTapped
        case cellTapped
        case deleteConversationButtonTapped
        case reportUsersButtonTapped
        case userInfoBadgeTapped

        case deleteConversationReturned(Exception?)
        case deletionActionSheetDismissed(cancelled: Bool)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        @Localized(.blockUser) public var blockUsersButtonText: String
        public var cellViewData: ConversationCellViewData = .empty
        public var conversation: Conversation
        @Localized(.delete) public var deleteConversationButtonText: String
        @Localized(.reportUser) public var reportUsersButtonText: String

        fileprivate var searchQuery: String

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

        public init(
            _ conversation: Conversation,
            searchQuery: String
        ) {
            self.conversation = conversation
            self.searchQuery = searchQuery
        }
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            guard let cellViewData = ConversationCellViewData(
                state.conversation,
                searchQuery: state.searchQuery
            ) else { return .none }

            state.cellViewData = cellViewData

        case .blockUsersButtonTapped:
            let conversation = state.conversation
            return .fireAndForget {
                guard let exception = await viewService.blockUsersButtonTapped(conversation) else { return }
                Logger.log(exception)
            }

        case .cellTapped:
            guard !state.searchQuery.isBlank,
                  let focusedMessageID = state
                  .conversation
                  .messages?
                  .last(where: { $0.textContains(state.searchQuery) })?
                  .id else {
                navigation.navigate(to: .userContent(.push(.chat(state.conversation))))
                return .none
            }

            navigation.navigate(to: .userContent(.push(.chat(
                state.conversation,
                focusedMessageID: focusedMessageID
            ))))

        case .deleteConversationButtonTapped:
            let title = state.cellViewData.titleLabelText
            return .task {
                let result = await viewService.presentDeletionActionSheet(title)
                return .deletionActionSheetDismissed(cancelled: result)
            }

        case let .deleteConversationReturned(exception):
            defer { clientSession.user.startObservingCurrentUserChanges() }

            guard let exception else {
                analyticsService.logEvent(.deleteConversation)
                return .none
            }

            Logger.log(exception, with: .toast)

        case let .deletionActionSheetDismissed(cancelled: cancelled):
            guard !cancelled else { return .none }

            clientSession.user.stopObservingCurrentUserChanges()
            let conversation = state.conversation
            return .task {
                let result = await clientSession.conversation.deleteConversation(conversation)
                return .deleteConversationReturned(result)
            }

        case .reportUsersButtonTapped:
            let conversation = state.conversation
            return .fireAndForget {
                guard let exception = await viewService.reportUsersButtonTapped(conversation) else { return }
                Logger.log(exception)
            }

        case .userInfoBadgeTapped:
            viewService.presentUserInfoAlert(state.cellViewData)
        }

        return .none
    }
}
