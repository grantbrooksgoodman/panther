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

struct FeaturePermissionPageReducer: Reducer {
    // MARK: - Types

    private enum NavigationDirection {
        case backward
        case forward
    }

    // MARK: - Dependencies

    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    enum Action {
        case viewAppeared

        case currentIndexChanged(Int)
        case declineButtonTapped
        case enableButtonTapped
        case getTranslationsReturned(Callback<[Translation], Exception>)
        case pageIndicatorTapped
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        let configurations: [FeaturePermissionPageView.Configuration]

        var currentIndex = 0
        var isButtonInteractionEnabled = true
        var viewState: StatefulView.ViewState = .loading

        fileprivate var previouslyEnabledIndices = [Int]()
        fileprivate var resolvedSubtitleText = [String]()
        fileprivate var resolvedTitleText = [String]()

        /* MARK: Computed Properties */

        @MainActor
        var accentColor: Color {
            currentConfig.accentColor ?? .init(uiColor: .accentOrSystemBlue)
        }

        var iconConfig: SquareIconView.Configuration {
            currentConfig.iconConfig
        }

        var subtitleText: String {
            (resolvedSubtitleText.itemAt(currentIndex) ??
                currentConfig.subtitleText).sanitized
        }

        var titleText: String {
            (resolvedTitleText.itemAt(currentIndex) ??
                currentConfig.titleText).sanitized
        }

        fileprivate var currentConfig: FeaturePermissionPageView.Configuration {
            configurations.itemAt(currentIndex) ?? .empty
        }

        /* MARK: Init */

        init(_ configurations: [FeaturePermissionPageView.Configuration]) {
            assert(
                !configurations.isEmpty,
                "Instantiated FeaturePermissionPageReducer.State with empty configurations array"
            )

            self.configurations = configurations
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading

            let titleTextInputs = state
                .configurations
                .map { TranslationInput($0.titleText) }

            let subtitleTextInputs = state
                .configurations
                .map { TranslationInput($0.subtitleText) }

            return .task {
                let result = await translator.getTranslations(
                    for: titleTextInputs + subtitleTextInputs,
                    languagePair: .system,
                    enhance: Networking.config.isEnhancedDialogTranslationEnabled ? .init(
                        additionalContext: nil
                    ) : nil
                )
                return .getTranslationsReturned(result)
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

        case let .getTranslationsReturned(.success(translations)):
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

        case let .getTranslationsReturned(.failure(exception)):
            Logger.log(exception)

            state.resolvedTitleText = state.configurations.map(\.titleText)
            state.resolvedSubtitleText = state.configurations.map(\.subtitleText)
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
