//
//  ConversationsPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public struct ConversationsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser?.conversations?.filteredAndSorted) private var conversations: [Conversation]?
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.review) private var reviewService: ReviewService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case viewDisappeared

        case animatedComposeToolbarButtonAppeared
        case composeToolbarButtonTapped
        case settingsToolbarButtonTapped

        case pulledToRefresh
        case traitCollectionChanged
        case updatedCurrentUser

        case composeToolbarButtonAnimationAmountSet(CGFloat)
        case reloadDataReturned(Callback<[Conversation], Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Array
        public var conversations = [Conversation]()
        public var strings: [TranslationOutputMap] = ConversationsPageViewStrings.defaultOutputMap

        // Bool
        public var isRefreshing = false

        // Other
        public var animationAmount: CGFloat = 1
        public var viewState: StatefulView.ViewState = .loading

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
            navigation.navigate(to: .userContent(.sheet(.newChat)))

        case .pulledToRefresh:
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
            Logger.log(exception, with: .toast())

        case let .resolveReturned(.success(strings)):
            state.strings = strings

            state.viewState = .loaded
            viewService.viewLoaded(state.conversations.isEmpty)

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)

            state.viewState = .loaded
            viewService.viewLoaded(state.conversations.isEmpty)

        case .settingsToolbarButtonTapped:
            navigation.navigate(to: .userContent(.sheet(.settings)))

        case .traitCollectionChanged:
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
                        with: isDeveloperModeEnabled ? .toast() : nil,
                        metadata: [self, #file, #function, #line]
                    )

                    coreGCD.after(.milliseconds(250)) { Observables.updatedCurrentUser.trigger() }
                    return true
                }

                return false
            }

            guard !refreshUsersIfNeeded() else { return .none }
            state.conversations = conversations ?? state.conversations
            return .task {
                .composeToolbarButtonAnimationAmountSet(1)
            }

        case .viewDisappeared:
            viewService.viewDisappeared()
        }

        return .none
    }
}
