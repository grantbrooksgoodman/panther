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

/* 3rd-party */
import Redux

public struct ConversationCellReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.conversationCellViewService) private var viewService: ConversationCellViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case chatInfoButtonTapped
        case chatPageViewAppeared
        case deleteConversationButtonTapped
        case userInfoBadgeTapped
    }

    // MARK: - Feedback

    public enum Feedback {
        case deleteConversationReturned(Exception?)
        case deletionActionSheetDismissed(cancelled: Bool)
        case updateCurrentUserBadgeNumberReturned(Exception?)
        case updateReadDateReturned(Callback<Conversation, Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public var cellViewData: ConversationCellViewData = .empty
        public var conversation: Conversation
        @Localized(.delete) public var deleteConversationButtonText: String
        public var isPresentingUserInfoAlert = false

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

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            guard let cellViewData = ConversationCellViewData(state.conversation) else { return .none }
            state.cellViewData = cellViewData

        case .action(.chatInfoButtonTapped):
            RootSheets.present(.chatInfoPageView)

        case .action(.chatPageViewAppeared):
            // TODO: In hindsight, it's a bit weird that this logic lives here instead of ChatPageViewService.
            let conversation = state.conversation

            guard let messages = conversation.messages?.filter({ !$0.isFromCurrentUser }),
                  messages.last?.readDate == nil else {
                return .none
            }

            let unreadMessages = messages.filter { $0.readDate == nil }
            guard !unreadMessages.isEmpty else { return .none }

            viewService.setBadgeDecrementAmount(unreadMessages.count)
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

        case .action(.userInfoBadgeTapped):
            Logger.log(
                "User info badge tapped.",
                metadata: [self, #file, #function, #line]
            )

        case let .feedback(.deleteConversationReturned(exception)):
            defer { clientSession.user.startObservingCurrentUserChanges() }
            guard let exception else { return .none }
            Logger.log(exception, with: .toast())

        case let .feedback(.deletionActionSheetDismissed(cancelled: cancelled)):
            guard !cancelled else { return .none }

            clientSession.user.stopObservingCurrentUserChanges()
            let conversation = state.conversation
            return .task {
                let result = await clientSession.conversation.deleteConversation(conversation)
                return .deleteConversationReturned(result)
            }

        case let .feedback(.updateCurrentUserBadgeNumberReturned(exception)):
            defer { viewService.setBadgeDecrementAmount(0) }
            guard let exception,
                  !exception.isEqual(to: .sameBadgeNumber) else { return .none }
            Logger.log(exception, with: .toast())

        case .feedback(.updateReadDateReturned(.success)):
            Logger.log(
                "Updated read date for \(viewService.badgeDecrementAmount) message\(viewService.badgeDecrementAmount == 1 ? "" : "s").",
                domain: .conversation,
                metadata: [self, #file, #function, #line]
            )

            clientSession.user.startObservingCurrentUserChanges()
            return .task {
                let result = await viewService.updateCurrentUserBadgeNumber()
                return .updateCurrentUserBadgeNumberReturned(result)
            }

        case let .feedback(.updateReadDateReturned(.failure(exception))):
            Logger.log(exception, with: .toast())
        }

        return .none
    }
}
