//
//  ConversationsPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the conversations page.
///
/// This page is the app's home, listing the user's conversations. It presents the conversations
/// sorted by their most recent message and filtered by the search query, and provides the entry
/// points for composing a new conversation and opening Settings.
///
/// The page's behavior contract:
///
/// - On first appearance, the page resolves its translated display strings, remaining in the
///   loading state until resolution completes.
/// - Pulling to refresh reloads the conversation data, unless a search is active.
/// - Session store changes refresh the list and reconcile it with changes originating from the
///   chat page.
/// - Tapping the compose button presents the new chat sheet, or the storage-full prompt when the
///   data usage limit has been reached; tapping the settings button presents the Settings sheet.
struct ConversationsPageReducer: Reducer {
    // MARK: - Types

    private enum TaskID: String {
        case handleChatPageStoreChange
    }

    // MARK: - Dependencies

    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.review) private var reviewService: ReviewService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Properties

    @SharedEvent(\.conversationsPageReappeared) private var conversationsPageReappeared
    @SharedState(\.conversationsSearchQuery) private var conversationsSearchQuery

    // MARK: - Actions

    /// The actions the conversations page can process.
    enum Action {
        /// An action that indicates the view appeared. On each appearance after the first,
        /// notifies observers so the conversation cells refresh.
        case viewAppeared

        /// An action that indicates the view disappeared.
        case viewDisappeared

        /// An action that indicates the view appeared for the first time. Begins display string
        /// resolution and resets the shared search query.
        case viewFirstAppeared

        /// An action that advances the compose button's pulsing animation.
        case animatedComposeToolbarButtonAppeared

        /// An action that indicates the user tapped the compose button. Presents the new chat
        /// sheet, or the storage-full prompt when the data usage limit has been reached.
        case composeToolbarButtonTapped

        /// An action that indicates the user tapped the settings button. Presents the Settings
        /// sheet.
        case settingsToolbarButtonTapped

        /// An action that indicates the user tapped the create-random-messages developer button.
        /// Performs the developer action that creates random messages.
        case createRandomMessagesToolbarButtonTapped

        /// An action that indicates the user tapped the delete-conversations developer button.
        /// Deletes the user's conversations.
        case deleteConversationsToolbarButtonTapped

        /// An action that reconciles the list with a pending change originating from the chat
        /// page.
        case handleChatPageStoreChange

        /// An action that indicates the user pulled to refresh. Reloads the conversation data,
        /// unless a search is active.
        case pulledToRefresh

        /// An action that indicates the session store changed. Refreshes the list and schedules
        /// handling of the change.
        case sessionStoreDidChange

        /// An action that indicates the trait collection changed. Rebuilds the compose button.
        case traitCollectionChanged

        /// An action that indicates whether the user is searching changed, carrying the new
        /// value.
        case isSearchingChanged(Bool)

        /// An action that indicates the search query changed, carrying the new value.
        case searchQueryChanged(String)

        /// An action that sets the compose button's animation amount, carrying the new value.
        case composeToolbarButtonAnimationAmountSet(CGFloat)

        /// An action that indicates a data reload failed, carrying the resulting `Exception`.
        case reloadDataFailed(Exception)

        /// An action that indicates a data reload finished.
        case reloadDataReturned

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    /// The state of the conversations page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The current scale of the compose button's pulsing animation.
        var animationAmount: CGFloat = 1

        /// The identity of the compose button. Regenerated to rebuild it when the trait
        /// collection changes.
        var composeToolbarButtonViewID = UUID()

        /// A token that changes to signal the conversation list to refresh.
        var conversationsChangeToken = UUID()

        /// A Boolean value that indicates whether a pull-to-refresh reload is in progress.
        var isRefreshing = false

        /// A Boolean value that indicates whether the user is currently searching.
        var isSearching = false

        /// The search query the user has entered.
        var searchQuery = ""

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = ConversationsPageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        fileprivate var didAppear = false

        /* MARK: Computed Properties */

        /// The current user's conversations, filtered for visibility,
        /// sorted by latest message sent date, and narrowed by the
        /// active search query when one is present.
        ///
        /// Falls back to the current chat session's conversation
        /// during the brief window between local conversation
        /// creation and server-side `conversationIDs` sync.
        ///
        /// Memoized against ``conversationsChangeToken`` and the search query, so its expensive resolution runs once per change rather than on every view body evaluation.
        @MainActor
        var conversations: [Conversation] {
            if ConversationsListMemo.token == conversationsChangeToken,
               ConversationsListMemo.searchQuery == searchQuery,
               let value = ConversationsListMemo.value {
                return value
            }

            let value = resolvedConversations
            ConversationsListMemo.token = conversationsChangeToken
            ConversationsListMemo.searchQuery = searchQuery
            ConversationsListMemo.value = value
            return value
        }

        @MainActor
        private var resolvedConversations: [Conversation] {
            @Dependency(\.clientSession.entity) var entitySession: EntitySession

            let allConversations = (
                entitySession.user.currentUser?.conversations ?? []
            ).filteredAndSorted

            guard !allConversations.isEmpty else {
                if let currentConversation = entitySession.conversation.currentConversation,
                   !currentConversation.isMock,
                   currentConversation.isVisibleForCurrentUser {
                    return [currentConversation].filteredAndSorted
                }

                return []
            }

            guard searchQuery.isEmpty else {
                return allConversations
                    .queried(by: searchQuery)
                    .filteredAndSorted
            }

            return allConversations
        }

        /// A Boolean value that indicates whether the extra developer toolbar buttons are shown.
        /// Shown only when Developer Mode is enabled and the app is connected to the staging
        /// environment, outside staging builds.
        @MainActor
        var shouldShowExtraToolbarButtons: Bool {
            @Dependency(\.build.isDeveloperModeEnabled) var isDeveloperModeEnabled: Bool
            guard !Application.isInStagingMode,
                  isDeveloperModeEnabled,
                  Networking.config.environment == .staging else { return false }
            return true
        }

        /// A Boolean value that indicates whether the storage-full button is shown. Shown when
        /// the data usage limit has been reached.
        var shouldShowStorageFullButton: Bool {
            @Dependency(\.dataUsageService.atOrAboveDataUsageLimit) var atOrAboveDataUsageLimit: Bool
            return atOrAboveDataUsageLimit
        }
    }

    // MARK: - Reduce

    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewFirstAppeared:
            state.viewState = .loading

            // Clears any query left in the shared stream by a previous
            // page instance; cells subscribe against this instance's
            // fresh state.
            conversationsSearchQuery = state.searchQuery

            viewService.viewAppeared()
            viewService.showSecondsToLoadToastIfNeeded()

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(ConversationsPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case .viewAppeared:
            guard state.didAppear else {
                state.didAppear = true
                return .none
            }

            // Session store changes are skipped while a
            // pushed page covers the list, so refresh the
            // memo on return.
            state.conversationsChangeToken = UUID()

            // Backstop for cell reloads lost while the list was covered
            // by a pushed page; cells re-derive their view data upon
            // reappearance.
            conversationsPageReappeared.send()

        case .animatedComposeToolbarButtonAppeared:
            let currentAnimationAmount = state.animationAmount
            return .task(delay: .seconds(1)) {
                .composeToolbarButtonAnimationAmountSet(currentAnimationAmount == 1.4 ? 1 : 1.4)
            }

        case let .composeToolbarButtonAnimationAmountSet(animationAmount):
            state.animationAmount = animationAmount

        case .composeToolbarButtonTapped:
            if state.shouldShowStorageFullButton {
                viewService.storageFullButtonTapped()
            } else {
                navigation.navigate(to: .userContent(.sheet(.newChat)))
            }

        case .createRandomMessagesToolbarButtonTapped:
            DevModeAction
                .AppActions
                .UserOptions
                .createNewMessagesAction
                .perform()

        case .deleteConversationsToolbarButtonTapped:
            viewService.deleteConversationsToolbarButtonTapped()

        case .handleChatPageStoreChange:
            return .fireAndForget { @MainActor in
                viewService.handleChatPageStoreChange()
            }

        case let .isSearchingChanged(isSearching):
            state.isSearching = isSearching

        case .pulledToRefresh:
            guard !state.isSearching else { return .none }
            state.isRefreshing = true
            return .task {
                do throws(Exception) {
                    try await viewService.reloadData()
                    return .reloadDataReturned
                } catch {
                    return .reloadDataFailed(error)
                }
            }

        case let .reloadDataFailed(exception):
            state.isRefreshing = false
            Logger.log(
                exception,
                with: .toast
            )

        case .reloadDataReturned:
            state.isRefreshing = false
            state.conversationsChangeToken = UUID()

        case let .resolveFailed(exception):
            Logger.log(exception)

            state.viewState = .loaded
            viewService.viewLoaded()

        case let .resolveReturned(strings):
            state.strings = strings
            state.viewState = .loaded
            viewService.viewLoaded()

        case let .searchQueryChanged(searchQuery):
            guard state.searchQuery != searchQuery else { return .none }
            state.searchQuery = searchQuery
            conversationsSearchQuery = searchQuery

        case .sessionStoreDidChange:
            guard navigation.state.modal == .userContent else { return handleChatPageStoreChangeTask }
            state.conversationsChangeToken = UUID()
            viewService.showSecondsToLoadToastIfNeeded()
            return handleChatPageStoreChangeTask

        case .settingsToolbarButtonTapped:
            navigation.navigate(to: .userContent(.sheet(.settings)))

        case .traitCollectionChanged:
            state.composeToolbarButtonViewID = UUID()
            viewService.traitCollectionChanged()

        case .viewDisappeared:
            viewService.viewDisappeared()
        }

        return .none
    }
}

private extension ConversationsPageReducer {
    var handleChatPageStoreChangeTask: Effect<Action> {
        .task(
            priority: .userInitiated,
            delay: .milliseconds(250)
        ) {
            .handleChatPageStoreChange
        }
        .cancellable(
            id: "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.handleChatPageStoreChange.rawValue)",
            cancelInFlight: true
        )
    }
}

/// In-memory memo for the resolved conversation list, keyed by the page's change token and
/// search query. One entry suffices: the home page is the sole resolver at any time.
@MainActor
private enum ConversationsListMemo {
    static var searchQuery: String?
    static var token: UUID?
    static var value: [Conversation]?
}
