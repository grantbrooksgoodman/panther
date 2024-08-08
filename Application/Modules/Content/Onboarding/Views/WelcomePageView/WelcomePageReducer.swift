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
import CoreArchitecture

public struct WelcomePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService

    // MARK: - Properties

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case viewFirstAppeared

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

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            core.utils.restoreDeviceLanguageCode()
            onboardingService.flushValues()

        case .action(.viewFirstAppeared):
            state.viewState = .loading
            core.ui.overrideUserInterfaceStyle(.unspecified)
            ThemeService.setTheme(AppTheme.default.theme, checkStyle: false)

            return .task {
                let result = await translator.resolve(WelcomePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.continueButtonTapped):
            navigationCoordinator.navigate(to: .onboarding(.push(.selectLanguage)))

        case .action(.signInButtonTapped):
            navigationCoordinator.navigate(to: .onboarding(.push(.signIn)))

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
