//
//  FeaturePermissionPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import Networking
import Translator

/// The reducer that drives the feature permission page.
///
/// This page presents a sequence of feature-permission prompts, one per step. Each step shows a
/// title, subtitle, and icon, and offers to enable or decline the corresponding feature. The user
/// pages through the prompts; enabling or declining advances to the next step, and advancing past
/// the last step dismisses the page.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves translations for every step's title and subtitle text,
///   remaining in the loading state until they resolve. If resolution fails, the page falls back
///   to the untranslated text.
/// - Each step displays the current prompt's title, subtitle, icon, and accent color.
/// - Tapping enable runs the current prompt's enable action; tapping decline runs its decline
///   action. Both advance to the next step, and advancing past the last step dismisses the page.
/// - The enable and decline buttons are not interactive on steps whose feature has already been
///   enabled.
struct FeaturePermissionPageReducer: Reducer {
    // MARK: - Types

    private enum NavigationDirection {
        case backward
        case forward
    }

    // MARK: - Dependencies

    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    /// The actions the feature permission page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins resolving translations for the
        /// steps' text.
        case viewAppeared

        /// An action that indicates the displayed step changed, carrying the new index.
        case currentIndexChanged(Int)

        /// An action that indicates the user tapped the decline button. Runs the current step's
        /// decline action and advances to the next step.
        case declineButtonTapped

        /// An action that indicates the user tapped the enable button. Runs the current step's
        /// enable action and advances to the next step.
        case enableButtonTapped

        /// An action that indicates translation resolution failed, carrying the resulting
        /// `Exception`. Falls back to the untranslated text.
        case getTranslationsFailed(Exception)

        /// An action that indicates translation resolution succeeded, carrying the resolved
        /// translations.
        case getTranslationsReturned([Translation])

        /// An action that indicates the user tapped the page indicator. Moves forward when in the
        /// first half of the steps, or backward otherwise.
        case pageIndicatorTapped
    }

    // MARK: - State

    /// The state of the feature permission page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The permission prompts to present, one per step.
        let configurations: [FeaturePermissionPageView.Configuration]

        /// The index of the step currently displayed.
        var currentIndex = 0

        /// A Boolean value that indicates whether the enable and decline buttons are interactive.
        /// Not interactive on steps whose feature has already been enabled.
        var isButtonInteractionEnabled = true

        /// The page's loading state. Remains `loading` until the steps' text is resolved.
        var viewState: StatefulView.ViewState = .loading

        fileprivate var previouslyEnabledIndices = [Int]()
        fileprivate var resolvedSubtitleText = [String]()
        fileprivate var resolvedTitleText = [String]()

        /* MARK: Computed Properties */

        /// The accent color for the current step.
        @MainActor
        var accentColor: Color {
            currentConfig.accentColor ?? .init(uiColor: .accentOrSystemBlue)
        }

        /// The icon configuration for the current step.
        var iconConfig: SquareIconView.Configuration {
            currentConfig.iconConfig
        }

        /// The subtitle text for the current step, translated when available.
        var subtitleText: String {
            (
                resolvedSubtitleText.itemAt(currentIndex) ??
                    currentConfig.subtitleText
            ).sanitized
        }

        /// The title text for the current step, translated when available.
        var titleText: String {
            (
                resolvedTitleText.itemAt(currentIndex) ??
                    currentConfig.titleText
            ).sanitized
        }

        fileprivate var currentConfig: FeaturePermissionPageView.Configuration {
            configurations.itemAt(currentIndex) ?? .empty
        }

        /* MARK: Init */

        /// Creates a state for the given permission prompts.
        ///
        /// - Parameter configurations: The permission prompts to present. Must not be empty.
        init(_ configurations: [FeaturePermissionPageView.Configuration]) {
            assert(
                !configurations.isEmpty,
                "Instantiated FeaturePermissionPageReducer.State with empty configurations array"
            )

            self.configurations = configurations
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

            let titleTextInputs = state
                .configurations
                .map { TranslationInput($0.titleText) }

            let subtitleTextInputs = state
                .configurations
                .map { TranslationInput($0.subtitleText) }

            return .task { @MainActor in
                do throws(Exception) {
                    return try await .getTranslationsReturned(
                        translator.getTranslations(
                            for: titleTextInputs + subtitleTextInputs,
                            languagePair: .system,
                            enhance: Networking.config.isEnhancedDialogTranslationEnabled ? .init(
                                additionalContext: nil
                            ) : nil
                        )
                    )
                } catch {
                    return .getTranslationsFailed(error)
                }
            }

        case let .currentIndexChanged(currentIndex):
            state.currentIndex = currentIndex
            state.isButtonInteractionEnabled = !state.previouslyEnabledIndices.contains(currentIndex)

        case .declineButtonTapped:
            state.currentConfig.declineButtonAction?()
            navigate(.forward, with: &state)

        case .enableButtonTapped:
            state.previouslyEnabledIndices.append(state.currentIndex)
            state.currentConfig.enableButtonAction()
            navigate(.forward, with: &state)

        case let .getTranslationsFailed(exception):
            Logger.log(exception)

            state.resolvedTitleText = state.configurations.map(\.titleText)
            state.resolvedSubtitleText = state.configurations.map(\.subtitleText)
            state.viewState = .loaded

        case let .getTranslationsReturned(translations):
            guard translations.count == state.configurations.count * 2 else {
                let exception = Exception(
                    "Mismatched ratio returned.",
                    metadata: .init(sender: self)
                )

                Logger.log(exception)
                state.viewState = .error(exception)
                return .none
            }

            let arrayMidpoint = translations.count / 2
            let titleText = translations[..<arrayMidpoint].map(\.output)
            let subtitleText = translations[arrayMidpoint...].map(\.output)

            state.resolvedTitleText = titleText
            state.resolvedSubtitleText = subtitleText

            state.viewState = .loaded

        case .pageIndicatorTapped:
            navigate(
                state.currentIndex < state.configurations.count / 2 ? .forward : .backward,
                with: &state
            )
        }

        return .none
    }

    // MARK: - Auxiliary

    private func navigate(
        _ direction: NavigationDirection,
        with state: inout FeaturePermissionPageReducer.State
    ) {
        let nextIndex = min(
            state.configurations.count - 1,
            state.currentIndex + 1
        )

        let previousIndex = max(
            0,
            state.currentIndex - 1
        )

        if direction == .forward,
           state.currentIndex == state.configurations.count - 1 {
            RootSheets.dismiss()
            return
        }

        state.currentIndex = direction == .forward ? nextIndex : previousIndex
        state.isButtonInteractionEnabled = !state
            .previouslyEnabledIndices
            .contains(state.currentIndex)
    }
}
