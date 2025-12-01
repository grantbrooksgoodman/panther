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

struct ChangeLanguagePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.settingsPageViewService) private var settingsPageViewService: SettingsPageViewService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.changeLanguagePageViewService) private var viewService: ChangeLanguagePageViewService

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case viewDisappeared

        case confirmButtonTapped
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case selectedLanguageNameChanged(String)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        // Array
        var languages: [String] = []
        var strings: [TranslationOutputMap] = ChangeLanguagePageViewStrings.defaultOutputMap

        // Other
        var instructionViewStrings: InstructionViewStrings = .empty
        var isConfirmButtonEnabled = false
        var selectedLanguageName = ""
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        fileprivate var selectedLanguageCode: String {
            @Dependency(\.coreKit.utils.localizedLanguageCodeDictionary) var localizedLanguageCodeDictionary: [String: String]?
            guard let localizedLanguageCodeDictionary,
                  let selectedLanguageCode = localizedLanguageCodeDictionary.keys(for: selectedLanguageName).first else { return RuntimeStorage.languageCode }
            return selectedLanguageCode
        }

        /* MARK: Init */

        init() {}
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            settingsPageViewService.isMainPagePresented = false

            guard let languageCodeDictionary = coreUtilities.localizedLanguageCodeDictionary else { return .none }

            state.languages = Array(languageCodeDictionary.values).sorted()
            state.selectedLanguageName = languageCodeDictionary[RuntimeStorage.languageCode] ?? languageCodeDictionary.values.first ?? ""

            return .task {
                let result = await translator.resolve(ChangeLanguagePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .confirmButtonTapped:
            viewService.confirmButtonTapped(state.selectedLanguageCode)

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
            state.isConfirmButtonEnabled = state.selectedLanguageCode != RuntimeStorage.languageCode

        case .viewDisappeared:
            settingsPageViewService.isMainPagePresented = true
            Observables.traitCollectionChanged.trigger()
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ChangeLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .changeLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
