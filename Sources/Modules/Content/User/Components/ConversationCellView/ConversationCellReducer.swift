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
    // MARK: - Types

    private enum TaskID: String {
        case reloadData
    }

    // MARK: - Dependencies

    @Dependency(\.commonServices.analytics) private var analyticsService: AnalyticsService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.conversationCellViewService) private var viewService: ConversationCellViewService

    // MARK: - Properties

    /// Scopes reload-task cancellation to this reducer instance; the
    /// cancellation registry is global, and sibling instances for the
    /// same conversation must not cancel each other's reloads.
    private let instanceID = UUID()

    // MARK: - Actions

    enum Action {
        case viewAppeared

        case blockUsersButtonTapped
        case cellTapped
        case deleteConversationButtonTapped
        case reloadData
        case reloadingConversationsChanged(Set<String>)
        case reportUsersButtonTapped
        case searchQueryChanged(String)
        case sessionStoreDidChange(SessionStoreChange)
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
        var isConversationReloading = false
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

        var dateLabelText: String {
            guard isShowingRedactedContent,
                  cellViewData.dateLabelText.isBlank else {
                return cellViewData.dateLabelText
            }

            return AppConstants.Strings.ConversationCellView.redactedDateLabelText
        }

        var focusedMessageID: String? {
            conversation.messages?.last(where: { $0.textContains(searchQuery) })?.id
        }

        var isShowingRedactedContent: Bool {
            cellViewData.isAwaitingMessageHydration || isConversationReloading
        }

        var subtitleLabelText: String {
            guard isShowingRedactedContent,
                  cellViewData.subtitleLabelText.isBlank else {
                return cellViewData.subtitleLabelText
            }

            return AppConstants.Strings.ConversationCellView.redactedSubtitleLabelText
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
            ) else {
                return reloadDataRetryTask(for: state.conversation)
            }

            state.cellViewData = cellViewData

            // Backstop for provisional builds; message hydration may
            // have completed before this cell subscribed to session
            // store changes.
            guard cellViewData.isAwaitingMessageHydration else { return .none }
            return .task(delay: .seconds(1)) { .reloadData }

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
                @Dependency(\.clientSession.entity.conversation) var conversationSession: ConversationSessionService
                do throws(Exception) {
                    try await conversationSession.deleteConversation(conversation)
                    return .deleteConversationReturned(nil)
                } catch {
                    return .deleteConversationReturned(error)
                }
            }

        case .reloadData:
            return reloadCellViewData(
                into: &state,
                useCachedValue: false
            )

        case let .reloadingConversationsChanged(conversationIDKeys):
            state.isConversationReloading = conversationIDKeys.contains(state.conversationIDKey)

        case .reportUsersButtonTapped:
            let conversation = state.conversation
            return .fireAndForget {
                do throws(Exception) {
                    try await viewService.reportUsersButtonTapped(conversation)
                } catch {
                    Logger.log(error)
                }
            }

        case let .searchQueryChanged(searchQuery):
            guard state.searchQuery != searchQuery else { return .none }
            state.searchQuery = searchQuery
            return reloadCellViewData(into: &state)

        case let .sessionStoreDidChange(change):
            guard isRelevantChange(
                change,
                for: state.conversation
            ) else { return .none }

            return .task(delay: .milliseconds(250)) {
                .reloadData
            }
            .cancellable(
                id: reloadDataTaskID,
                cancelInFlight: true
            )

        case .userInfoBadgeTapped:
            guard let otherUser = state.cellViewData.otherUser else { return .none }
            viewService.presentUserInfoAlert(otherUser)
        }

        return .none
    }
}

private extension ConversationCellReducer {
    // MARK: - Properties

    var reloadDataTaskID: String {
        "\(String.fromCurrentEditorContext(sender: self))/\(instanceID)/\(TaskID.reloadData.rawValue)"
    }

    // MARK: - Methods

    func isRelevantChange(
        _ change: SessionStoreChange,
        for conversation: Conversation
    ) -> Bool {
        switch change {
        case let .conversations(upsertedIDKeys, removedIDKeys):
            upsertedIDKeys.contains(conversation.id.key) ||
                removedIDKeys.contains(conversation.id.key)

        case let .messages(upsertedIDs, removedIDs):
            !Set(
                conversation.messageIDs
            ).isDisjoint(with: upsertedIDs.union(removedIDs))

        case let .users(upsertedIDs, removedIDs):
            !Set(
                conversation.participants.map(\.userID)
            ).isDisjoint(with: upsertedIDs.union(removedIDs))
        }
    }

    func reloadCellViewData(
        into state: inout State,
        useCachedValue: Bool = true
    ) -> Effect<Action> {
        guard let cellViewData = ConversationCellViewData(
            state.conversation,
            searchQuery: state.searchQuery,
            useCachedValue: useCachedValue
        ) else {
            return reloadDataRetryTask(for: state.conversation)
        }

        guard cellViewData != state.cellViewData else { return .none }
        state.cellViewData = cellViewData
        return .none
    }

    /// Retries the reload rather than consuming it; participants or
    /// messages may still be hydrating into the session store.
    func reloadDataRetryTask(for conversation: Conversation) -> Effect<Action> {
        guard !conversation.isEmpty else { return .none }
        return .task(delay: .seconds(1)) {
            .reloadData
        }
        .cancellable(
            id: reloadDataTaskID,
            cancelInFlight: true
        )
    }
}
