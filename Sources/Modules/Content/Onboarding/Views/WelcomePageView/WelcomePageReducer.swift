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
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case viewFirstAppeared

        case continueButtonTapped
        case signInButtonTapped
        case welcomeLabelTapped

        case cycleWelcomeLabelText
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Types */

        fileprivate enum TaskID {
            case cycleWelcomeLabelText
        }

        /* MARK: Properties */

        public var strings: [TranslationOutputMap] = WelcomePageViewStrings.defaultOutputMap
        public var viewState: StatefulView.ViewState = .loading
        public var welcomeLabelText = Localized(.welcomeToHello).wrappedValue

        fileprivate var cycledLanguageCodes = [String: String]()

        /* MARK: Computed Properties */

        fileprivate var supportedLanguageCodes: [String] {
            guard let languageCodeDictionary = RuntimeStorage.languageCodeDictionary else { return [] }
            return Array(languageCodeDictionary.keys)
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.welcomeLabelText = Localized(
                .welcomeToHello,
                languageCode: Locale.systemLanguageCode
            ).wrappedValue
            core.utils.restoreDeviceLanguageCode()
            onboardingService.flushValues()

        case .viewFirstAppeared:
            state.viewState = .loading
            core.ui.overrideUserInterfaceStyle(.unspecified)
            ThemeService.setTheme(UITheme.appDefault, checkStyle: false)

            return .task {
                let result = await translator.resolve(WelcomePageViewStrings.self)
                return .resolveReturned(result)
            }.merge(with: cycleWelcomeLabelTextEffect(delay: .seconds(5)))

        case .continueButtonTapped:
            navigation.navigate(to: .onboarding(.push(.selectLanguage)))

        case .cycleWelcomeLabelText:
            guard state.cycledLanguageCodes.count < state.supportedLanguageCodes.count else {
                state.cycledLanguageCodes = [:]
                return cycleWelcomeLabelTextEffect()
            }

            guard let randomLanguageCode = state.supportedLanguageCodes.randomElement() else {
                return cycleWelcomeLabelTextEffect()
            }

            let localizedString = Localized(
                .welcomeToHello,
                languageCode: randomLanguageCode
            ).wrappedValue

            guard state.cycledLanguageCodes[randomLanguageCode] == nil,
                  !state.cycledLanguageCodes.values.contains(localizedString),
                  state.welcomeLabelText != localizedString else {
                return cycleWelcomeLabelTextEffect()
            }

            state.cycledLanguageCodes[randomLanguageCode] = localizedString
            state.welcomeLabelText = localizedString

            return cycleWelcomeLabelTextEffect(delay: .seconds(3))

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded

        case .signInButtonTapped:
            navigation.navigate(to: .onboarding(.push(.signIn)))

        case .welcomeLabelTapped:
            state.welcomeLabelText = Localized(.welcomeToHello).wrappedValue
            return .cancel(id: State.TaskID.cycleWelcomeLabelText)
                .merge(with: cycleWelcomeLabelTextEffect(delay: .seconds(5)))
        }

        return .none
    }

    // MARK: - Auxiliary

    private func cycleWelcomeLabelTextEffect(delay: Duration = .zero) -> Effect<Action> {
        guard delay == .zero else {
            return .task(delay: delay) {
                .cycleWelcomeLabelText
            }.cancellable(id: State.TaskID.cycleWelcomeLabelText)
        }

        return .task {
            .cycleWelcomeLabelText
        }.cancellable(id: State.TaskID.cycleWelcomeLabelText)
    }
}
