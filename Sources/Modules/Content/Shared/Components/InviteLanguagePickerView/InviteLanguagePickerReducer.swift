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

/// The reducer that drives ``InviteLanguagePickerView``.
///
/// The picker's behavior contract:
///
/// - On appearance, the picker clears its search query and selection and disables the done
///   button.
/// - The list displays the languages whose names match the search query, or a no results message
///   when none match. While the query is empty, all supported languages are shown.
/// - Selecting a language enables the done button.
/// - Tapping done dismisses the sheet and, after a short delay, composes the invitation in the
///   selected language, surfacing any error as a toast. Tapping cancel dismisses the sheet
///   without composing an invitation.
struct InviteLanguagePickerReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.commonServices.invite) private var inviteService: InviteService

    // MARK: - Actions

    /// The actions the invite language picker can process.
    enum Action {
        /// An action that indicates the view appeared. Resets the picker's selection and search
        /// query.
        case viewAppeared

        /// An action that indicates the view disappeared. Restores the conversations page's
        /// navigation bar appearance when applicable.
        case viewDisappeared

        /// An action that indicates the user tapped the cancel button. Dismisses the sheet.
        case cancelHeaderItemTapped

        /// An action that indicates the user tapped the done button. Dismisses the sheet and
        /// begins composing the invitation.
        case doneHeaderItemTapped

        /// An action that indicates the search query changed, carrying the new value.
        case searchQueryChanged(String)

        /// An action that indicates the user selected a language, carrying its language code.
        /// Enables the done button.
        case selectedLanguageCodeChanged(String)
    }

    // MARK: - State

    /// The state of the invite language picker.
    struct State: Equatable {
        /* MARK: Properties */

        /// The localized text the cancel button displays.
        @Localized(.cancel) var cancelHeaderItemText: String

        /// The localized text the done button displays.
        @Localized(.done) var doneHeaderItemText: String

        /// A Boolean value that indicates whether the done button is enabled. Enabled once a
        /// language has been selected.
        var isDoneHeaderItemEnabled = false

        /// The localized text the no results label displays.
        @Localized(.noResults) var noResultsLabelText: String

        /// The search query the user has entered.
        var searchQuery = ""

        /// The language code of the selected language.
        var selectedLanguageCode = ""

        /* MARK: Computed Properties */

        /// The selectable languages, keyed by language code, with localized display names as
        /// values.
        var localizedLanguageNames: [String: String] {
            @Dependency(\.coreKit.utils.localizedLanguageCodeDictionary) var localizedLanguageCodeDictionary: [String: String]?
            return localizedLanguageCodeDictionary ?? RuntimeStorage.languageCodeDictionary ?? .init()
        }

        /// The localized text the picker's header displays.
        var navigationTitle: String {
            let localizedString = Localized(.selectLanguage).wrappedValue
            guard RuntimeStorage.languageCode == "en" else { return localizedString }
            return localizedString.capitalized
        }

        /// The languages whose display names match the search query, keyed by language code.
        var queriedLanguageNames: [String: String] {
            localizedLanguageNames.filter {
                $0.value.lowercasedTrimmingWhitespaceAndNewlines.contains(searchQuery.lowercasedTrimmingWhitespaceAndNewlines)
            }
        }
    }

    // MARK: - Reduce

    /// Updates the picker's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The picker's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
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
            Task.delayed(by: .seconds(2)) { @MainActor in
                do throws(Exception) {
                    try await inviteService.composeInvitation(
                        languageCode: languageCode
                    )
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
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
