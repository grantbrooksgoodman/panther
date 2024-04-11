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

    @Dependency(\.clientSession.user.currentUser?.conversations?.filteredAndSorted) private var conversations: [Conversation]?
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case composeToolbarButtonTapped
        case settingsToolbarButtonTapped

        case pulledToRefresh
        case traitCollectionChanged
        case updatedContactPairArchive
        case updatedCurrentUser

        case isPresentingNewChatSheetChanged(Bool)
        case isPresentingSettingsSheetChanged(Bool)
    }

    // MARK: - Feedback

    public enum Feedback {
        case reloadDataReturned(Callback<[Conversation], Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
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

        // Array
        public var conversations = [Conversation]()
        public var strings: [TranslationOutputMap] = ConversationsPageViewStrings.defaultOutputMap

        // Bool
        public var isPresentingNewChatSheet = false
        public var isPresentingSettingsSheet = false

        // Other
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
        case let .action(action):
            return reduce(into: &state, for: action)

        case let .feedback(feedback):
            return reduce(into: &state, for: feedback)
        }
    }

    // MARK: - Reduce Action

    private func reduce(into state: inout State, for action: Action) -> Effect<Feedback> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.conversations = conversations ?? []

            viewService.viewAppeared()

            return .task {
                let result = await translator.resolve(ConversationsPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .composeToolbarButtonTapped:
            state.isPresentingNewChatSheet = true

        case let .isPresentingNewChatSheetChanged(isPresentingNewChatSheet):
            state.isPresentingNewChatSheet = isPresentingNewChatSheet

        case let .isPresentingSettingsSheetChanged(isPresentingSettingsSheet):
            state.isPresentingSettingsSheet = isPresentingSettingsSheet

        case .pulledToRefresh:
            return .task {
                let result = await viewService.reloadData()
                return .reloadDataReturned(result)
            }

        case .settingsToolbarButtonTapped:
            state.isPresentingSettingsSheet = true

        case .traitCollectionChanged,
             .updatedContactPairArchive:
            NavigationBar.setAppearance(.appDefault)
            state.viewID = UUID()

        case .updatedCurrentUser:
            state.conversations = conversations ?? state.conversations
        }

        return .none
    }

    // MARK: - Reduce Feedback

    private func reduce(into state: inout State, for feedback: Feedback) -> Effect<Feedback> {
        switch feedback {
        case let .reloadDataReturned(.success(conversations)):
            state.conversations = conversations.filteredAndSorted

        case let .reloadDataReturned(.failure(exception)):
            Logger.log(exception, with: .toast())

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded
        }

        return .none
    }
}
