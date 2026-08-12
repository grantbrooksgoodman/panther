//
//  SelectLanguagePageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

/// The reducer that drives the language selection page of the onboarding flow.
///
/// This page is the first step of sign-up. The user chooses the language the app's content is
/// translated into, and the reducer commits the choice before phone number verification begins.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings, remaining in the loading
///   state until resolution completes. If resolution fails, the page falls back to its default
///   strings and loads anyway.
/// - The page builds its language list from the localized language code dictionary, selecting the
///   app's current language by default. If the dictionary is unavailable, the page enters the
///   error state instead.
/// - Tapping continue clears the language-dependent caches, sets the app's language to the
///   selection, records the choice with ``OnboardingService/setLanguageCode(_:)``, and pushes the
///   phone number entry page.
struct SelectLanguagePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    /// The actions the language selection page can process.
    enum Action {
        /// An action that indicates the view appeared. Builds the language list and begins
        /// display string resolution.
        case viewAppeared

        /// An action that indicates the user tapped the back button. Pops the current page.
        case backButtonTapped

        /// An action that indicates the user tapped the continue button. Commits the selected
        /// language and pushes the phone number entry page.
        case continueButtonTapped

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])

        /// An action that indicates the selected language changed, carrying the new language's
        /// display name.
        case selectedLanguageNameChanged(String)
    }

    // MARK: - State

    /// The state of the language selection page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The strings the page's instruction header displays. Populated once display string
        /// resolution completes.
        var instructionViewStrings: InstructionViewStrings = .empty

        /// The display names of the selectable languages, sorted alphabetically.
        var languages: [String] = []

        /// The display name of the selected language.
        var selectedLanguageName = ""

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = SelectLanguagePageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        fileprivate var selectedLanguageCode: String {
            @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
            guard let selectedLanguageCode = coreUtilities
                .localizedLanguageCodeDictionary(for: Locale.systemLanguageCode)?
                .keys(for: selectedLanguageName)
                .first else { return RuntimeStorage.languageCode }
            return selectedLanguageCode
        }
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
            state.viewState = .loading

            guard let localizedLanguageCodeDictionary = coreUtilities.localizedLanguageCodeDictionary else {
                let exception = Exception(
                    "No localized language code dictionary.",
                    metadata: .init(sender: self)
                )

                Logger.log(exception)
                state.viewState = .error(exception)
                return .none
            }

            state.languages = Array(localizedLanguageCodeDictionary.values).sorted()
            state.selectedLanguageName = localizedLanguageCodeDictionary[RuntimeStorage.languageCode] ?? localizedLanguageCodeDictionary.values.first ?? ""

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(SelectLanguagePageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

        case .continueButtonTapped:
            coreUtilities.clearCaches(
                [
                    .activityDescription,
                    .conversationCellViewData,
                    .localization,
                    .regionDetailService,
                ]
            )

            coreUtilities.setLanguageCode(state.selectedLanguageCode)

            navigation.navigate(to: .onboarding(.push(.verifyNumber)))
            onboardingService.setLanguageCode(state.selectedLanguageCode)

        case let .resolveFailed(exception):
            Logger.log(exception)
            state.instructionViewStrings = .init(
                titleLabelText: state.strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: state.strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
            state.instructionViewStrings = .init(
                titleLabelText: strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .selectedLanguageNameChanged(selectedLanguageName):
            state.selectedLanguageName = selectedLanguageName
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.SelectLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .selectLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
