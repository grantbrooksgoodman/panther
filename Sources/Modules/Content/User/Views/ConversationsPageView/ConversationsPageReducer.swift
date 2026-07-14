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

struct ConversationsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.review) private var reviewService: ReviewService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case viewDisappeared

        case animatedComposeToolbarButtonAppeared
        case composeToolbarButtonTapped
        case settingsToolbarButtonTapped

        case createRandomMessagesToolbarButtonTapped
        case deleteConversationsToolbarButtonTapped

        case pulledToRefresh
        case sessionStoreDidChange
        case traitCollectionChanged

        case isSearchingChanged(Bool)
        case searchQueryChanged(String)

        case composeToolbarButtonAnimationAmountSet(CGFloat)
        case reloadDataFailed(Exception)
        case reloadDataReturned
        case resolveFailed(Exception)
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var animationAmount: CGFloat = 1
        var composeToolbarButtonViewID = UUID()
        var conversationsChangeToken = UUID()
        var isRefreshing = false
        var isSearching = false
        var searchQuery = ""
        var strings: [TranslationOutputMap] = ConversationsPageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        /// The current user's conversations, filtered for visibility,
        /// sorted by latest message sent date, and narrowed by the
        /// active search query when one is present.
        ///
        /// Falls back to the current chat session's conversation
        /// during the brief window between local conversation
        /// creation and server-side `conversationIDs` sync.
        @MainActor
        var conversations: [Conversation] {
            @Dependency(\.clientSession) var clientSession: ClientSession

            let allConversations = (
                clientSession.user.currentUser?.conversations ?? []
            ).filteredAndSorted

            guard !allConversations.isEmpty else {
                if let currentConversation = clientSession.conversation.currentConversation,
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

        @MainActor
        var shouldShowExtraToolbarButtons: Bool {
            @Dependency(\.build.isDeveloperModeEnabled) var isDeveloperModeEnabled: Bool
            guard !Application.isInStagingMode,
                  isDeveloperModeEnabled,
                  Networking.config.environment == .staging else { return false }
            return true
        }

        var shouldShowStorageFullButton: Bool {
            @Dependency(\.clientSession.storage.atOrAboveDataUsageLimit) var atOrAboveDataUsageLimit: Bool
            return atOrAboveDataUsageLimit
        }
    }

    // MARK: - Reduce

    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading

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
            DevModeAction.AppActions.createNewMessagesAction.perform()

        case .deleteConversationsToolbarButtonTapped:
            viewService.deleteConversationsToolbarButtonTapped()

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

        case .sessionStoreDidChange:
            guard navigation.state.modal == .userContent else { return .none }
            state.conversationsChangeToken = UUID()
            viewService.showSecondsToLoadToastIfNeeded()

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
