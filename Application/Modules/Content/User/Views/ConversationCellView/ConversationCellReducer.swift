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

    @Dependency(\.clientSessionService.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.conversationCellViewService) private var viewService: ConversationCellViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

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

        // Color
        public var chevronImageForegroundColor: Color = .init(uiColor: .subtitleText.lighter(by: 60) ?? .subtitleText)
        public var subtitleLabelTextForegroundColor: Color = .init(
            uiColor: .subtitleText.lighter(
                by: AppConstants.CGFloats.ConversationCellView.subtitleLabelForegroundColorAdjustmentPercentage
            ) ?? .subtitleText
        )

        // Other
        public var cellViewData: ConversationCellViewData = .empty
        public var conversation: Conversation
        public var isPresentingUserInfoAlert = false

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
            guard let cellViewData = viewService.cellViewData(for: state.conversation) else { return .none }
            state.cellViewData = cellViewData

        case .action(.chatPageViewAppeared):
            @Persistent(.currentUserID) var currentUserID: String?
            let conversation = state.conversation

            guard let messages = conversation.messages?.filter({ $0.fromAccountID != currentUserID }),
                  messages.last?.readDate == nil else {
                return .none
            }

            let unreadMessages = messages.filter { $0.readDate == nil }
            guard !unreadMessages.isEmpty else { return .none }

            viewService.setBadgeDecrementAmount(unreadMessages.count)
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
            guard let exception else { return .none }
            Logger.log(exception, with: .toast())

        case let .feedback(.deletionActionSheetDismissed(cancelled: cancelled)):
            guard !cancelled else { return .none }

            let conversation = state.conversation
            return .task {
                let result = await conversationSession.deleteConversation(conversation)
                return .deleteConversationReturned(result)
            }

        case let .feedback(.updateCurrentUserBadgeNumberReturned(exception)):
            defer { viewService.setBadgeDecrementAmount(0) }
            guard let exception else { return .none }
            Logger.log(exception, with: .toast())

        case .feedback(.updateReadDateReturned(.success)):
            Logger.log(
                "Updated read date for \(viewService.badgeDecrementAmount) message\(viewService.badgeDecrementAmount == 1 ? "s" : "").",
                domain: .conversation,
                metadata: [self, #file, #function, #line]
            )

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
