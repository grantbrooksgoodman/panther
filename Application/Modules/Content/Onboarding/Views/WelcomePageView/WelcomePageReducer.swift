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

public struct WelcomePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.rootNavigationCoordinator) private var navigationCoordinator: RootNavigationCoordinator
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
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
            core.utils.restoreDeviceLanguageCode()
            core.ui.overrideUserInterfaceStyle(.unspecified)
            ThemeService.setTheme(AppTheme.default.theme, checkStyle: false)
            onboardingService.flushValues()

            return .task {
                let result = await translator.resolve(WelcomePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.continueButtonTapped):
            navigationCoordinator.setPage(.onboarding(.selectLanguage))

        case .action(.signInButtonTapped):
            navigationCoordinator.setPage(.onboarding(.signIn))

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
