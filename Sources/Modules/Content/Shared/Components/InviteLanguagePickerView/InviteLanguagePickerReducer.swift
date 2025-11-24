//
//  InviteLanguagePickerReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct InviteLanguagePickerReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices.invite) private var inviteService: InviteService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case cancelHeaderItemTapped
        case doneHeaderItemTapped

        case searchQueryChanged(String)
        case selectedLanguageCodeChanged(String)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        @Localized(.cancel) public var cancelHeaderItemText: String
        @Localized(.done) public var doneHeaderItemText: String
        public var isDoneHeaderItemEnabled = false
        @Localized(.selectLanguage) public var navigationTitle: String
        @Localized(.noResults) public var noResultsLabelText: String
        public var searchQuery = ""
        public var selectedLanguageCode = ""

        /* MARK: Computed Properties */

        public var doneHeaderItemForegroundColor: Color {
            guard UIApplication.isGlassTintingEnabled,
                  !isChatPagePresented else { return .navigationBarButton }
            return .white
        }

        public var isChatPagePresented: Bool {
            Dependency(\.chatPageStateService.isPresented).wrappedValue
        }

        public var localizedLanguageNames: [String: String] {
            @Dependency(\.coreKit.utils.localizedLanguageCodeDictionary) var localizedLanguageCodeDictionary: [String: String]?
            return localizedLanguageCodeDictionary ?? RuntimeStorage.languageCodeDictionary ?? .init()
        }

        public var queriedLanguageNames: [String: String] {
            localizedLanguageNames.filter {
                $0.value.lowercasedTrimmingWhitespaceAndNewlines.contains(searchQuery.lowercasedTrimmingWhitespaceAndNewlines)
            }
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
        }

        return .none
    }
}
