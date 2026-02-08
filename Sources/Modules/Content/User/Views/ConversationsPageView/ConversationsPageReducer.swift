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

    @Dependency(\.clientSession.user.currentUser?.conversations?.filteredAndSorted) private var conversations: [Conversation]?
    @Dependency(\.coreKit) private var core: CoreKit
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
        case traitCollectionChanged
        case updatedCurrentUser

        case isSearchingChanged(Bool)
        case searchQueryChanged(String)

        case composeToolbarButtonAnimationAmountSet(CGFloat)
        case reloadDataReturned(Callback<[Conversation], Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var animationAmount: CGFloat = 1
        var composeToolbarButtonViewID = UUID()
        var conversationCellViewID = UUID()
        var conversations = [Conversation]()
        var isRefreshing = false
        var isSearching = false
        var searchQuery = ""
        var strings: [TranslationOutputMap] = ConversationsPageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        var shouldShowExtraToolbarButtons: Bool {
            @Dependency(\.build.isDeveloperModeEnabled) var isDeveloperModeEnabled: Bool
            return Networking.config.environment == .staging && isDeveloperModeEnabled
        }

        var shouldShowStorageFullButton: Bool {
            @Dependency(\.clientSession.storage.atOrAboveDataUsageLimit) var atOrAboveDataUsageLimit: Bool
            return atOrAboveDataUsageLimit
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.conversations = conversations ?? []

            viewService.viewAppeared()

            return .task {
                let result = await translator.resolve(ConversationsPageViewStrings.self)
                return .resolveReturned(result)
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
                let result = await viewService.reloadData()
                return .reloadDataReturned(result)
            }

        case let .reloadDataReturned(.success(conversations)):
            state.isRefreshing = false
            state.conversations = conversations.filteredAndSorted

        case let .reloadDataReturned(.failure(exception)):
            state.isRefreshing = false
            Logger.log(exception, with: .toast)

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded
            viewService.viewLoaded()

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)

            state.viewState = .loaded
            viewService.viewLoaded()

        case let .searchQueryChanged(searchQuery):
            guard state.searchQuery != searchQuery else { return .none }
            state.searchQuery = searchQuery

            defer { state.conversationCellViewID = UUID() }
            guard !searchQuery.isEmpty else {
                state.conversations = conversations ?? state.conversations
                return .none
            }

            state.conversations = (conversations ?? state.conversations)
                .queried(by: searchQuery)
                .filteredAndSorted

        case .settingsToolbarButtonTapped:
            navigation.navigate(to: .userContent(.sheet(.settings)))

        case .traitCollectionChanged:
            state.composeToolbarButtonViewID = UUID()
            viewService.traitCollectionChanged()

        case .updatedCurrentUser:
            /// - NOTE: Fixes a bug in which mistimed updates would fail to set users on all conversations.
            /// - Returns: `true` if the page needed refreshing.
            func refreshUsersIfNeeded() -> Bool {
                guard let conversations else { return false }
                guard conversations.allSatisfy({ $0.users != nil }) else {
                    Logger.log(
                        "Intercepted badly set users on conversations bug.",
                        domain: .bugPrevention,
                        with: isDeveloperModeEnabled ? .toast : nil,
                        sender: self
                    )

                    core.gcd.after(.milliseconds(250)) { Observables.updatedCurrentUser.trigger() }
                    return true
                }

                return false
            }

            guard !refreshUsersIfNeeded() else { return .none }

            state.conversations = conversations ?? state.conversations.filteredAndSorted
            state.isSearching = false
            state.searchQuery = ""
            core.utils.clearCaches([.queriedConversations])

            return .task {
                .composeToolbarButtonAnimationAmountSet(1)
            }

        case .viewDisappeared:
            viewService.viewDisappeared()
        }

        return .none
    }
}
