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

public struct SelectLanguagePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped

        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case selectedLanguageNameChanged(String)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Array
        public var languages: [String] = []
        public var strings: [TranslationOutputMap] = SelectLanguagePageViewStrings.defaultOutputMap

        // Other
        public var instructionViewStrings: InstructionViewStrings = .empty
        public var selectedLanguageName = ""
        public var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        fileprivate var selectedLanguageCode: String {
            @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
            guard let selectedLanguageCode = coreUtilities
                .localizedLanguageCodeDictionary(for: Locale.systemLanguageCode)?
                .keys(for: selectedLanguageName)
                .first else { return RuntimeStorage.languageCode }
            return selectedLanguageCode
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
                let result = await translator.resolve(SelectLanguagePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

        case .continueButtonTapped:
            coreUtilities.clearCaches([.localization, .regionDetailService])
            coreUtilities.setLanguageCode(state.selectedLanguageCode)

            navigation.navigate(to: .onboarding(.push(.verifyNumber)))
            onboardingService.setLanguageCode(state.selectedLanguageCode)

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.instructionViewStrings = .init(
                titleLabelText: strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.instructionViewStrings = .init(
                titleLabelText: state.strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: state.strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .selectedLanguageNameChanged(selectedLanguageName):
            state.selectedLanguageName = selectedLanguageName
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SelectLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .selectLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
