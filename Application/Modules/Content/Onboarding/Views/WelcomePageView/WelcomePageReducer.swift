//
//  WelcomePageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public struct WelcomePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.navigation) private var navigation: NavigationCoordinator<RootNavigationService>
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.translationService) private var translator: HostedTranslationService

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case viewFirstAppeared

        case continueButtonTapped
        case signInButtonTapped

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

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            core.utils.restoreDeviceLanguageCode()
            onboardingService.flushValues()

        case .viewFirstAppeared:
            state.viewState = .loading
            core.ui.overrideUserInterfaceStyle(.unspecified)
            ThemeService.setTheme(AppTheme.appDefault.theme, checkStyle: false)

            return .task {
                let result = await translator.resolve(WelcomePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .continueButtonTapped:
            navigation.navigate(to: .onboarding(.push(.selectLanguage)))

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded

        case .signInButtonTapped:
            navigation.navigate(to: .onboarding(.push(.signIn)))
        }

        return .none
    }
}
