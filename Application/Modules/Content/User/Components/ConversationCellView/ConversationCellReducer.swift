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

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.chatPageViewService.mediaMessagePreview) private var mediaMessagePreviewService: MediaMessagePreviewService?
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.conversationCellViewService) private var viewService: ConversationCellViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case blockUsersButtonTapped
        case chatInfoToolbarButtonTapped
        case chatPageViewAppeared
        case deleteConversationButtonTapped
        case reportUsersButtonTapped
        case userInfoBadgeTapped
    }

    // MARK: - Feedback

    public enum Feedback {
        case deleteConversationReturned(Exception?)
        case deletionActionSheetDismissed(cancelled: Bool)
        case modifyBadgeNumberReturned(Exception?)
        case updateReadDateReturned(Callback<Conversation, Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // String
        @Localized(.blockUser) public var blockUsersButtonText: String
        @Localized(.delete) public var deleteConversationButtonText: String
        @Localized(.reportUser) public var reportUsersButtonText: String

        // Other
        public var badgeDecrementAmount = 0
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

        case .action(.chatInfoToolbarButtonTapped):
            return .fireAndForget {
                Task { @MainActor in
                    RootSheets.present(.chatInfoPageView)
                }
            }

        case .action(.chatPageViewAppeared):
            services.analytics.logEvent(.accessChat)
            guard !(mediaMessagePreviewService?.isPreviewingMedia ?? false) else { return .none }

            // NIT: In hindsight, it's a bit weird that this logic lives here instead of ChatPageViewService.
            let conversation = state.conversation

            guard let messages = conversation.messages?.filter({ !$0.isFromCurrentUser }),
                  messages.last?.readDate == nil else {
                return .none
            }

            let unreadMessages = messages.filter { $0.readDate == nil }
            guard !unreadMessages.isEmpty else { return .none }

            state.badgeDecrementAmount = unreadMessages.count
            clientSession.user.stopObservingCurrentUserChanges()
            return .task {
                let result = await conversation.updateReadDate(for: unreadMessages)
                return .updateReadDateReturned(result)
            }

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
                services.analytics.logEvent(.deleteConversation)
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

        case let .feedback(.modifyBadgeNumberReturned(exception)):
            defer { state.badgeDecrementAmount = 0 }
            guard let exception else { return .none }
            Logger.log(exception, with: .toast())

        case .feedback(.updateReadDateReturned(.success)):
            Logger.log(
                "Updated read date for \(state.badgeDecrementAmount) message\(state.badgeDecrementAmount == 1 ? "" : "s").",
                domain: .conversation,
                metadata: [self, #file, #function, #line]
            )

            clientSession.user.startObservingCurrentUserChanges()

            let badgeDecrementAmount = state.badgeDecrementAmount
            return .task {
                let result = await services.notification.modifyBadgeNumber(.decrement(by: badgeDecrementAmount))
                return .modifyBadgeNumberReturned(result)
            }

        case let .feedback(.updateReadDateReturned(.failure(exception))):
            Logger.log(exception)
        }

        return .none
    }
}
