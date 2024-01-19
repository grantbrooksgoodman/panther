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
    }

    // MARK: - Feedback

    public enum Feedback {
        case reloadDataReturned(Callback<[Conversation], Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case setUsersReturned(Exception?)
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
        public var viewID = UUID()
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
            state.conversations = userSessionService.currentUser?.conversations ?? []

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

        case .action(.updatedCurrentUser):
            return .task {
                let result = await userSessionService.currentUser?.conversations?.setUsers()
                return .setUsersReturned(result)
            }

        case let .feedback(.reloadDataReturned(.success(conversations))):
            state.conversations = conversations
            state.viewID = .init()

        case let .feedback(.reloadDataReturned(.failure(exception))):
            Logger.log(exception, with: .toast())

        case let .feedback(.resolveReturned(.success(strings))):
            state.strings = strings
            state.viewState = .loaded

        case let .feedback(.resolveReturned(.failure(exception))):
            Logger.log(exception)
            state.viewState = .loaded

        case let .feedback(.setUsersReturned(exception)):
            if let exception {
                Logger.log(exception, with: .toast())
            } else {
                state.conversations = userSessionService.currentUser?.conversations ?? []
            }
        }

        return .none
    }
}
