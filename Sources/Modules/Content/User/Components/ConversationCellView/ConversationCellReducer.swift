//
//  ConversationCellReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

/// The reducer that drives ``ConversationCellView``.
///
/// The cell's behavior contract:
///
/// - On first appearance, the cell loads its view data, retrying after a short delay if it is
///   not yet available.
/// - Tapping the cell opens the chat page for the conversation; when a search query is active,
///   the chat focuses the most recent matching message.
/// - Deleting the conversation requires confirmation through an action sheet; success logs an
///   analytics event, and failure surfaces as a toast.
/// - The cell redacts its content while messages hydrate or the conversation reloads.
/// - When the session store reports a change affecting the conversation, its messages, or its
///   participants, the cell reloads after a short delay; rapid successive changes coalesce
///   into a single reload.
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

    /// The actions the conversation cell can process.
    enum Action {
        /// An action that indicates the view appeared. Loads the cell's view data, retrying
        /// after a short delay if it is not yet available.
        case viewAppeared

        /// An action that indicates the user tapped the block users button. Begins the block
        /// users flow for the conversation, logging any error.
        case blockUsersButtonTapped

        /// An action that indicates the user tapped the cell. Opens the chat page for the
        /// conversation, focusing the most recent message matching the search query when one
        /// is active.
        case cellTapped

        /// An action that indicates the user tapped the delete button. Presents the deletion
        /// confirmation action sheet.
        case deleteConversationButtonTapped

        /// An action that reloads the cell's view data, disregarding any cached value.
        case reloadData

        /// An action that indicates the set of reloading conversations changed, carrying the
        /// affected conversation ID keys. Updates whether the cell shows redacted content.
        case reloadingConversationsChanged(Set<String>)

        /// An action that indicates the user tapped the report users button. Begins the report
        /// users flow for the conversation, logging any error.
        case reportUsersButtonTapped

        /// An action that indicates the search query changed, carrying the new value. Reloads
        /// the cell's view data when the query differs.
        case searchQueryChanged(String)

        /// An action that indicates the session store changed, carrying the change. Reloads
        /// the cell after a short delay when the change affects the conversation, its
        /// messages, or its participants.
        case sessionStoreDidChange(SessionStoreChange)

        /// An action that indicates the user tapped the user info badge. Presents an alert
        /// with information about the other user.
        case userInfoBadgeTapped

        /// An action that indicates conversation deletion finished, carrying an `Exception`
        /// if it failed. Logs an analytics event on success; otherwise, surfaces the error as
        /// a toast.
        case deleteConversationReturned(Exception?)

        /// An action that indicates the deletion action sheet was dismissed, carrying whether
        /// the user canceled. Deletes the conversation unless canceled.
        case deletionActionSheetDismissed(cancelled: Bool)
    }

    // MARK: - State

    /// The state of the conversation cell.
    struct State: Equatable {
        /* MARK: Properties */

        /// The localized text the block users button displays.
        @Localized(.blockUser) var blockUsersButtonText: String

        /// The view data used to render the cell's content.
        var cellViewData: ConversationCellViewData = .empty

        /// The localized text the delete button displays.
        @Localized(.delete) var deleteConversationButtonText: String

        /// A Boolean value that indicates whether the conversation is being reloaded.
        var isConversationReloading = false

        /// The localized text the report users button displays.
        @Localized(.reportUser) var reportUsersButtonText: String

        fileprivate let conversationIDKey: String

        fileprivate var searchQuery: String

        /* MARK: Computed Properties */

        /// The conversation the cell describes, resolved from the session store – an empty
        /// placeholder if it no longer exists.
        var conversation: Conversation {
            @Dependency(\.clientSession.store) var sessionStore: SessionStore
            return sessionStore.getConversation(
                idKey: conversationIDKey
            ) ?? .empty
        }

        /// The foreground color of the cell's chevron symbol, adjusted for the active theme.
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

        /// The text the date label displays, or a redaction placeholder while content is
        /// redacted.
        var dateLabelText: String {
            guard isShowingRedactedContent,
                  cellViewData.dateLabelText.isBlank else {
                return cellViewData.dateLabelText
            }

            return AppConstants.Strings.ConversationCellView.redactedDateLabelText
        }

        /// The ID of the most recent message matching the search query, or `nil` if none
        /// match.
        var focusedMessageID: String? {
            conversation.messages?.last(where: { $0.textContains(searchQuery) })?.id
        }

        /// A Boolean value that indicates whether the cell redacts its content – `true` while
        /// messages hydrate or the conversation reloads.
        var isShowingRedactedContent: Bool {
            cellViewData.isAwaitingMessageHydration || isConversationReloading
        }

        /// The text the subtitle label displays, or a redaction placeholder while content is
        /// redacted.
        var subtitleLabelText: String {
            guard isShowingRedactedContent,
                  cellViewData.subtitleLabelText.isBlank else {
                return cellViewData.subtitleLabelText
            }

            return AppConstants.Strings.ConversationCellView.redactedSubtitleLabelText
        }

        /// The foreground color of the subtitle label.
        @MainActor
        var subtitleLabelTextForegroundColor: Color {
            .init(
                uiColor: .subtitleText.lighter(
                    by: AppConstants.CGFloats.ConversationCellView.subtitleLabelForegroundColorAdjustmentPercentage
                ) ?? .subtitleText
            )
        }

        /* MARK: Init */

        /// Creates the state for the conversation with the given ID key.
        ///
        /// - Parameters:
        ///   - conversationIDKey: The ID key of the conversation the cell describes.
        ///   - searchQuery: The search query active when the cell was created.
        init(
            _ conversationIDKey: String,
            searchQuery: String
        ) {
            self.conversationIDKey = conversationIDKey
            self.searchQuery = searchQuery
        }
    }

    // MARK: - Reduce

    /// Updates the cell's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The cell's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
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

// swiftlint:enable file_length
