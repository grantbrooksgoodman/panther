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

struct ConversationCellReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.analytics) private var analyticsService: AnalyticsService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.conversationCellViewService) private var viewService: ConversationCellViewService

    // MARK: - Actions

    enum Action {
        case viewAppeared

        case blockUsersButtonTapped
        case cellTapped
        case deleteConversationButtonTapped
        case refreshCellData
        case reportUsersButtonTapped
        case userInfoBadgeTapped

        case deleteConversationReturned(Exception?)
        case deletionActionSheetDismissed(cancelled: Bool)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        @Localized(.blockUser) var blockUsersButtonText: String
        var cellViewData: ConversationCellViewData = .empty
        @Localized(.delete) var deleteConversationButtonText: String
        @Localized(.reportUser) var reportUsersButtonText: String

        fileprivate let conversationIDKey: String

        fileprivate var searchQuery: String

        /* MARK: Computed Properties */

        var conversation: Conversation {
            @Dependency(\.clientSession.store) var sessionStore: SessionStore
            return sessionStore.getConversation(
                idKey: conversationIDKey
            ) ?? .empty
        }

        @MainActor
        var chevronImageForegroundColor: Color {
            guard ThemeService.isDarkModeActive else {
                return .init(
                    uiColor: .titleText.lighter(by: AppConstants.CGFloats.ConversationCellView.chevronImageForegroundColorAdjustmentPercentage) ?? .titleText
                )
            }

            return .init(
                uiColor: .titleText.darker(by: AppConstants.CGFloats.ConversationCellView.chevronImageForegroundColorAdjustmentPercentage) ?? .titleText
            )
        }

        var focusedMessageID: String? {
            conversation.messages?.last(where: { $0.textContains(searchQuery) })?.id
        }

        @MainActor
        var subtitleLabelTextForegroundColor: Color {
            .init(
                uiColor: .subtitleText.lighter(
                    by: AppConstants.CGFloats.ConversationCellView.subtitleLabelForegroundColorAdjustmentPercentage
                ) ?? .subtitleText
            )
        }

        /* MARK: Init */

        init(
            _ conversationIDKey: String,
            searchQuery: String
        ) {
            self.conversationIDKey = conversationIDKey
            self.searchQuery = searchQuery
        }
    }

    // MARK: - Reduce

    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
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
                do throws(Exception) {
                    try await viewService.blockUsersButtonTapped(conversation)
                } catch {
                    Logger.log(error)
                }
            }

        case .cellTapped:
            guard !state.searchQuery.isBlank,
                  let focusedMessageID = state.focusedMessageID else {
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
            guard let exception else {
                analyticsService.logEvent(.deleteConversation)
                return .none
            }

            Logger.log(
                exception,
                with: .toast
            )

        case let .deletionActionSheetDismissed(cancelled: cancelled):
            guard !cancelled else { return .none }

            let conversation = state.conversation
            return .task {
                @Dependency(\.clientSession.conversation) var conversationSession: ConversationSessionService
                do throws(Exception) {
                    try await conversationSession.deleteConversation(conversation)
                    return .deleteConversationReturned(nil)
                } catch {
                    return .deleteConversationReturned(error)
                }
            }

        case .refreshCellData:
            guard let cellViewData = ConversationCellViewData(
                state.conversation,
                searchQuery: state.searchQuery,
                useCachedValue: false
            ), cellViewData != state.cellViewData else { return .none }

            state.cellViewData = cellViewData

        case .reportUsersButtonTapped:
            let conversation = state.conversation
            return .fireAndForget {
                do throws(Exception) {
                    try await viewService.reportUsersButtonTapped(conversation)
                } catch {
                    Logger.log(error)
                }
            }

        case .userInfoBadgeTapped:
            guard let otherUser = state.cellViewData.otherUser else { return .none }
            viewService.presentUserInfoAlert(otherUser)
        }

        return .none
    }
}
