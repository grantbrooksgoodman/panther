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

/* 3rd-party */
import Redux

public struct InviteLanguagePickerReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices.invite) private var inviteService: InviteService

    // MARK: - Actions

    public enum Action {
        case cancelHeaderItemTapped
        case doneHeaderItemTapped

        case searchQueryChanged(String)
        case selectedLanguageCodeChanged(String)

        case traitCollectionChanged
        case viewDisappeared
    }

    // MARK: - Feedback

    public typealias Feedback = Never

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isDoneHeaderItemEnabled = false
        public var traitCollectionChanged = false

        // String
        @Localized(.cancel) public var cancelHeaderItemText: String
        @Localized(.done) public var doneHeaderItemText: String
        @Localized(.selectLanguage) public var navigationTitle: String
        @Localized(.noResults) public var noResultsLabelText: String
        public var searchQuery = ""
        public var selectedLanguageCode = ""

        /* MARK: Computed Properties */

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

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.cancelHeaderItemTapped):
            RootSheets.dismiss()

        case .action(.doneHeaderItemTapped):
            RootSheets.dismiss()

            let languageCode = state.selectedLanguageCode
            coreGCD.after(.seconds(2)) {
                Task {
                    if let exception = await inviteService.composeInvitation(languageCode: languageCode) {
                        Logger.log(exception, with: .toast())
                    }
                }
            }

        case let .action(.searchQueryChanged(searchQuery)):
            state.searchQuery = searchQuery

        case let .action(.selectedLanguageCodeChanged(selectedLanguageCode)):
            state.selectedLanguageCode = selectedLanguageCode
            state.isDoneHeaderItemEnabled = true

        case .action(.traitCollectionChanged):
            state.traitCollectionChanged = true

        case .action(.viewDisappeared):
            NavigationBar.setAppearance(.appDefault)
            guard state.traitCollectionChanged else { return .none }
            Observables.traitCollectionChanged.trigger()
        }

        return .none
    }
}
