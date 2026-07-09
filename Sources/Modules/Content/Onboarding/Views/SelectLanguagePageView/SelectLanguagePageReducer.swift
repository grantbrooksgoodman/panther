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

struct SelectLanguagePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped

        case resolveFailed(Exception)
        case resolveReturned([TranslationOutputMap])
        case selectedLanguageNameChanged(String)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var instructionViewStrings: InstructionViewStrings = .empty
        var languages: [String] = []
        var selectedLanguageName = ""
        var strings: [TranslationOutputMap] = SelectLanguagePageViewStrings.defaultOutputMap
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
