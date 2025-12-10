//
//  InviteLanguagePickerReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct InviteLanguagePickerReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices.invite) private var inviteService: InviteService

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case viewDisappeared

        case cancelHeaderItemTapped
        case doneHeaderItemTapped

        case searchQueryChanged(String)
        case selectedLanguageCodeChanged(String)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        @Localized(.cancel) var cancelHeaderItemText: String
        @Localized(.done) var doneHeaderItemText: String
        var isDoneHeaderItemEnabled = false
        @Localized(.selectLanguage) var navigationTitle: String
        @Localized(.noResults) var noResultsLabelText: String
        var searchQuery = ""
        var selectedLanguageCode = ""

        /* MARK: Computed Properties */

        var localizedLanguageNames: [String: String] {
            @Dependency(\.coreKit.utils.localizedLanguageCodeDictionary) var localizedLanguageCodeDictionary: [String: String]?
            return localizedLanguageCodeDictionary ?? RuntimeStorage.languageCodeDictionary ?? .init()
        }

        var queriedLanguageNames: [String: String] {
            localizedLanguageNames.filter {
                $0.value.lowercasedTrimmingWhitespaceAndNewlines.contains(searchQuery.lowercasedTrimmingWhitespaceAndNewlines)
            }
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.isDoneHeaderItemEnabled = false

            state.searchQuery = ""
            state.selectedLanguageCode = ""

        case .cancelHeaderItemTapped:
            RootSheets.dismiss()

        case .doneHeaderItemTapped:
            guard state.isDoneHeaderItemEnabled else { return .none }
            RootSheets.dismiss()

            let languageCode = state.selectedLanguageCode
            coreGCD.after(.seconds(2)) {
                Task {
                    if let exception = await inviteService.composeInvitation(languageCode: languageCode) {
                        Logger.log(exception, with: .toast)
                    }
                }
            }

        case let .searchQueryChanged(searchQuery):
            state.searchQuery = searchQuery

        case let .selectedLanguageCodeChanged(selectedLanguageCode):
            state.selectedLanguageCode = selectedLanguageCode
            state.isDoneHeaderItemEnabled = true

        case .viewDisappeared:
            guard Application.isInPrevaricationMode,
                  !chatPageState.isPresented else { return .none }
            NavigationBar.setAppearance(.conversationsPageView)
        }

        return .none
    }
}
