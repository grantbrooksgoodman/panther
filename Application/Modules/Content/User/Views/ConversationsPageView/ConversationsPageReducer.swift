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

    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case composeToolbarButtonTapped
        case settingsToolbarButtonTapped

        case pulledToRefresh
        case updatedContactPairArchive
        case updatedCurrentUser

        // swiftlint:disable:next identifier_name
        case isPresentingInviteLanguagePickerSheetChanged(Bool)
        case isPresentingSettingsSheetChanged(Bool)
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

        // Array
        public var conversations = [Conversation]()
        public var strings: [TranslationOutputMap] = ConversationsPageViewStrings.defaultOutputMap

        // Bool
        public var isPresentingInviteLanguagePickerSheet = false
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
            state.conversations = currentUser?.conversations?.visibleForCurrentUser.sortedByLatestMessageSentDate.unique ?? []

            viewService.viewAppeared()

            return .task {
                let result = await translator.resolve(ConversationsPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .composeToolbarButtonTapped:
            Logger.log(
                "Compose toolbar button tapped.",
                metadata: [self, #file, #function, #line]
            )

        case let .isPresentingInviteLanguagePickerSheetChanged(isPresentingInviteLanguagePickerSheet):
            state.isPresentingInviteLanguagePickerSheet = isPresentingInviteLanguagePickerSheet

        case let .isPresentingSettingsSheetChanged(isPresentingSettingsSheet):
            state.isPresentingSettingsSheet = isPresentingSettingsSheet

        case .pulledToRefresh:
            return .task {
                let result = await viewService.reloadData()
                return .reloadDataReturned(result)
            }

        case .settingsToolbarButtonTapped:
            state.isPresentingSettingsSheet = true

        case .updatedContactPairArchive:
            state.viewID = UUID()

        case .updatedCurrentUser:
            return .task {
                let result = await viewService.updatedCurrentUser()
                return .updatedCurrentUserReturned(result)
            }
        }

        return .none
    }

    // MARK: - Reduce Feedback

    private func reduce(into state: inout State, for feedback: Feedback) -> Effect<Feedback> {
        switch feedback {
        case let .reloadDataReturned(.success(conversations)):
            state.conversations = conversations.visibleForCurrentUser.sortedByLatestMessageSentDate.unique

        case let .reloadDataReturned(.failure(exception)):
            Logger.log(exception, with: .toast())

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded

        case let .updatedCurrentUserReturned(exception):
            guard let exception else {
                let conversations = currentUser?.conversations?.visibleForCurrentUser.sortedByLatestMessageSentDate.unique
                state.conversations = conversations ?? state.conversations
                return .none
            }

            Logger.log(exception, with: .toast())
        }

        return .none
    }
}
