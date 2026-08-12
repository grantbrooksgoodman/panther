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

/// The reducer that drives the welcome page, the root of the onboarding flow.
///
/// This page is the user's entry point into the app. It offers two paths forward: continuing to
/// sign-up, which begins with language selection, or signing in to an existing account.
///
/// The page's behavior contract:
///
/// - On first appearance, the page resolves its translated display strings, remaining in the
///   loading state until resolution completes. If resolution fails, the page falls back to its
///   default strings and loads anyway. The page also resets the app's theme to its default,
///   clears the application badge, and begins cycling the welcome label.
/// - On every appearance, the page restores the device's language code, discards any values
///   recorded by ``OnboardingService`` during a previous onboarding attempt, and signs the user
///   in anonymously after a brief delay.
/// - The welcome label displays the welcome message in a randomly chosen supported language every
///   few seconds, not repeating a language until all have been shown. Tapping the label resets it
///   and restarts the cycling loop.
/// - Tapping continue pushes the language selection page; tapping sign in pushes the sign-in
///   page.
struct WelcomePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Actions

    /// The actions the welcome page can process.
    enum Action {
        /// An action that indicates the view appeared. Resets the welcome label, restores the
        /// device's language code, discards any values recorded by ``OnboardingService`` during a
        /// previous onboarding attempt, and signs the user in anonymously after a brief delay.
        case viewAppeared

        /// An action that indicates the view appeared for the first time. Begins display string
        /// resolution, resets the app's theme, clears the application badge, and begins cycling
        /// the welcome label.
        case viewFirstAppeared

        /// An action that indicates the user tapped the continue button. Pushes the language
        /// selection page.
        case continueButtonTapped

        /// An action that indicates the user tapped the sign in button. Pushes the sign-in page.
        case signInButtonTapped

        /// An action that indicates the user tapped the welcome label. Resets the label and
        /// restarts the cycling loop.
        case welcomeLabelTapped

        /// An action that displays the welcome message in a randomly chosen supported language,
        /// then schedules the next cycle. Languages do not repeat until all have been shown.
        case cycleWelcomeLabelText

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    /// The state of the welcome page.
    struct State: Equatable {
        /* MARK: Types */

        fileprivate enum TaskID {
            case cycleWelcomeLabelText
        }

        /* MARK: Properties */

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = WelcomePageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        /// The text the welcome label displays. Cycles through the supported languages while the
        /// page is visible.
        var welcomeLabelText = Localized(.welcomeToHello).wrappedValue

        fileprivate var cycledLanguageCodes = [String: String]()

        /* MARK: Computed Properties */

        fileprivate let supportedLanguageCodes: [String] = {
            guard let languageCodeDictionary = RuntimeStorage.languageCodeDictionary else { return [] }
            return Array(languageCodeDictionary.keys)
        }()
    }

    // MARK: - Reduce

    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
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
            return .task(delay: .seconds(1)) {
                do throws(Exception) {
                    _ = try await auth.wrappedValue.signInAnonymously()
                } catch {
                    Logger.log(
                        error,
                        with: .toastInPrerelease
                    )
                }

                return .none
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
