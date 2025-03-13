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

public struct SelectLanguagePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.navigation) private var navigation: NavigationCoordinator<RootNavigationService>
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.translationService) private var translator: HostedTranslationService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped

        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case selectedLanguageChanged(String)
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

        // Array
        public var languages: [String] = []
        public var strings: [TranslationOutputMap] = SelectLanguagePageViewStrings.defaultOutputMap

        // Other
        public var instructionViewStrings: InstructionViewStrings = .empty
        public var selectedLanguage = ""
        public var viewState: ViewState = .loading

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            coreUtilities.restoreDeviceLanguageCode()

            guard let localizedLanguageCodeDictionary = coreUtilities.localizedLanguageCodeDictionary else {
                state.viewState = .error(.init("No localized language code dictionary.", metadata: [self, #file, #function, #line]))
                return .none
            }

            state.languages = Array(localizedLanguageCodeDictionary.values).sorted()
            state.selectedLanguage = localizedLanguageCodeDictionary[RuntimeStorage.languageCode] ?? localizedLanguageCodeDictionary.values.first ?? ""

            return .task {
                let result = await translator.resolve(SelectLanguagePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

        case .continueButtonTapped:
            coreUtilities.restoreDeviceLanguageCode()
            guard let localizedLanguageCodeDictionary = coreUtilities.localizedLanguageCodeDictionary else {
                state.viewState = .error(.init("No localized language code dictionary.", metadata: [self, #file, #function, #line]))
                return .none
            }

            if let selectedLanguageCode = localizedLanguageCodeDictionary.keys(for: state.selectedLanguage).first {
                coreUtilities.clearCaches([.localization, .regionDetailService])
                coreUtilities.setLanguageCode(selectedLanguageCode)

                navigation.navigate(to: .onboarding(.push(.verifyNumber)))
                onboardingService.setLanguageCode(selectedLanguageCode)
            }

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

        case let .selectedLanguageChanged(selectedLanguage):
            state.selectedLanguage = selectedLanguage
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SelectLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .selectLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
