//
//  ChangeLanguagePageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

/// The reducer that drives the change language page.
///
/// This page lets the user change the language the app's content is translated into from
/// Settings. The user selects a language, and the reducer applies the change through
/// ``ChangeLanguagePageViewService``.
///
/// The page's behavior contract:
///
/// - On appearance, the page builds its language list from the localized language code
///   dictionary, selecting the app's current language by default, and resolves its translated
///   display strings, remaining in the loading state until resolution completes. If resolution
///   fails, the page falls back to its default strings and loads anyway.
/// - The confirm button is enabled only while the selected language differs from the current
///   language.
/// - Tapping confirm applies the selected language.
struct ChangeLanguagePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.settingsPageViewService) private var settingsPageViewService: SettingsPageViewService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.changeLanguagePageViewService) private var viewService: ChangeLanguagePageViewService

    // MARK: - Properties

    @SharedEvent(\.traitCollectionChanged) private var traitCollectionChanged

    // MARK: - Actions

    /// The actions the change language page can process.
    enum Action {
        /// An action that indicates the view appeared. Builds the language list, begins display
        /// string resolution, and marks the settings page's main view as not presented.
        case viewAppeared

        /// An action that indicates the view disappeared. Marks the settings page's main view as
        /// presented again and notifies observers that the trait collection changed.
        case viewDisappeared

        /// An action that indicates the user tapped the confirm button. Applies the selected
        /// language.
        case confirmButtonTapped

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

    /// The state of the change language page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The strings the page's instruction header displays. Populated once display string
        /// resolution completes.
        var instructionViewStrings: InstructionViewStrings = .empty

        /// A Boolean value that indicates whether the confirm button is enabled. Enabled only
        /// while the selected language differs from the current language.
        var isConfirmButtonEnabled = false

        /// The display names of the selectable languages, sorted alphabetically.
        var languages: [String] = []

        /// The display name of the selected language.
        var selectedLanguageName = ""

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = ChangeLanguagePageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        fileprivate var selectedLanguageCode: String {
            @Dependency(\.coreKit.utils.localizedLanguageCodeDictionary) var localizedLanguageCodeDictionary: [String: String]?
            guard let localizedLanguageCodeDictionary,
                  let selectedLanguageCode = localizedLanguageCodeDictionary.keys(for: selectedLanguageName).first else { return RuntimeStorage.languageCode }
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
            settingsPageViewService.isMainPagePresented = false

            guard let languageCodeDictionary = coreUtilities.localizedLanguageCodeDictionary else { return .none }

            state.languages = Array(languageCodeDictionary.values).sorted()
            state.selectedLanguageName = languageCodeDictionary[RuntimeStorage.languageCode] ?? languageCodeDictionary.values.first ?? ""

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(ChangeLanguagePageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case .confirmButtonTapped:
            viewService.confirmButtonTapped(state.selectedLanguageCode)

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
            state.isConfirmButtonEnabled = state.selectedLanguageCode != RuntimeStorage.languageCode

        case .viewDisappeared:
            settingsPageViewService.isMainPagePresented = true
            traitCollectionChanged.send()
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.ChangeLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .changeLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
