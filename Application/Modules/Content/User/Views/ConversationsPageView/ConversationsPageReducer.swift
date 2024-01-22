//
//  ConversationsPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import Redux

public struct ConversationsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService
    @Dependency(\.clientSessionService.user) private var userSessionService: UserSessionService
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case pulledToRefresh
        case updatedCurrentUser

        case settingsToolbarButtonTapped
    }

    // MARK: - Feedback

    public enum Feedback {
        case reloadDataReturned(Callback<[Conversation], Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case updatedCurrentUserReturned(Exception?)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Types */

        public enum ViewState: Equatable {
            case loading
            case error(Exception)
            case loaded
        }

        /* MARK: Properties */

        public var conversations = [Conversation]()
        public var strings: [TranslationOutputMap] = ConversationsPageViewStrings.defaultOutputMap
        public var viewState: ViewState = .loading

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            state.viewState = .loading
            state.conversations = userSessionService.currentUser?.conversations?.visibleForCurrentUser.sortedByLatestMessageSentDate.unique ?? []

            viewService.viewAppeared()

            return .task {
                let result = await translator.resolve(ConversationsPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.pulledToRefresh):
            return .task {
                let result = await viewService.reloadData()
                return .reloadDataReturned(result)
            }

        case .action(.settingsToolbarButtonTapped):
            Logger.log(
                "Settings toolbar button tapped.",
                metadata: [self, #file, #function, #line]
            )

        case .action(.updatedCurrentUser):
            return .task {
                let result = await viewService.updatedCurrentUser()
                return .updatedCurrentUserReturned(result)
            }

        case let .feedback(.reloadDataReturned(.success(conversations))):
            state.conversations = conversations.visibleForCurrentUser.sortedByLatestMessageSentDate.unique

        case let .feedback(.reloadDataReturned(.failure(exception))):
            Logger.log(exception, with: .toast())

        case let .feedback(.resolveReturned(.success(strings))):
            state.strings = strings
            state.viewState = .loaded

        case let .feedback(.resolveReturned(.failure(exception))):
            Logger.log(exception)
            state.viewState = .loaded

        case let .feedback(.updatedCurrentUserReturned(exception)):
            guard let exception else {
                state.conversations = userSessionService.currentUser?.conversations?.visibleForCurrentUser.sortedByLatestMessageSentDate.unique ?? []
                return .none
            }

            Logger.log(exception, with: .toast())
        }

        return .none
    }
}
