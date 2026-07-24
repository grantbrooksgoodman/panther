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

struct WelcomePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case viewFirstAppeared

        case continueButtonTapped
        case signInButtonTapped
        case welcomeLabelTapped

        case cycleWelcomeLabelText
        case resolveFailed(Exception)
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Types */

        fileprivate enum TaskID {
            case cycleWelcomeLabelText
        }

        /* MARK: Properties */

        var strings: [TranslationOutputMap] = WelcomePageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading
        var welcomeLabelText = Localized(.welcomeToHello).wrappedValue

        fileprivate var cycledLanguageCodes = [String: String]()

        /* MARK: Computed Properties */

        fileprivate let supportedLanguageCodes: [String] = {
            guard let languageCodeDictionary = RuntimeStorage.languageCodeDictionary else { return [] }
            return Array(languageCodeDictionary.keys)
        }()
    }

    // MARK: - Reduce

    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.welcomeLabelText = Localized(
                .welcomeToHello,
                languageCode: Locale.systemLanguageCode
            ).wrappedValue

            core.utils.restoreDeviceLanguageCode()
            onboardingService.flushValues()

            let auth = LockIsolated(networking.auth)
            return .fireAndForget {
                do throws(Exception) {
                    _ = try await auth.wrappedValue.signInAnonymously()
                } catch {
                    Logger.log(
                        error,
                        with: .toastInPrerelease
                    )
                }
            }

        case .viewFirstAppeared:
            state.viewState = .loading
            core.ui.overrideUserInterfaceStyle(.unspecified)
            ThemeService.setTheme(UITheme.appDefault, checkStyle: false)

            let resetBadgeNumberEffect: Effect<Action> = .fireAndForget {
                do throws(Exception) {
                    try await notificationService.setBadgeNumber(
                        0,
                        updateHostedValue: false
                    )
                } catch {
                    Logger.log(error)
                }
            }

            let translator = LockIsolated(networking.hostedTranslation)
            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.wrappedValue.resolve(
                            WelcomePageViewStrings.self
                        )
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }.merge(
                with: resetBadgeNumberEffect
            )
            .merge(
                with: cycleWelcomeLabelTextEffect(delay: .seconds(5))
            )

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

        case let .resolveFailed(exception):
            Logger.log(exception)
            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
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
