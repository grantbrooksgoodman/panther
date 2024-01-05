//
//  WelcomePageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import Translator

public struct WelcomePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.rootNavigationCoordinator) private var navigationCoordinator: RootNavigationCoordinator
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case continueButtonTapped
        case signInButtonTapped
    }

    // MARK: - Feedback

    public enum Feedback {
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

        public var strings: [TranslationOutputMap] = WelcomePageViewStrings.defaultOutputMap
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
            coreUtilities.restoreDeviceLanguageCode()

            return .task {
                let result = await translator.resolve(WelcomePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.continueButtonTapped):
            navigationCoordinator.setPage(.onboarding(.selectLanguage))

        case .action(.signInButtonTapped):
            navigationCoordinator.setPage(.sample)

        case let .feedback(.resolveReturned(.success(strings))):
            state.strings = strings
            state.viewState = .loaded

        case let .feedback(.resolveReturned(.failure(exception))):
            Logger.log(exception)
            state.viewState = .loaded
        }

        return .none
    }
}
