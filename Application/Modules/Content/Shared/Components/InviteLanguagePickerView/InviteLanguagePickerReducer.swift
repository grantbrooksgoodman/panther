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
    }

    // MARK: - Feedback

    public typealias Feedback = Never

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isDoneHeaderItemEnabled = false
        public var isPresented: Binding<Bool>

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

        public init(_ isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        /* MARK: Equatable Conformance */

        public static func == (left: State, right: State) -> Bool {
            let sameCancelHeaderItemText = left.cancelHeaderItemText == right.cancelHeaderItemText
            let sameDoneHeaderItemText = left.doneHeaderItemText == right.doneHeaderItemText
            let sameIsDoneHeaderItemEnabled = left.isDoneHeaderItemEnabled == right.isDoneHeaderItemEnabled
            let sameIsPresented = left.isPresented.wrappedValue == right.isPresented.wrappedValue
            let sameLocalizedLanguageNames = left.localizedLanguageNames == right.localizedLanguageNames
            let sameQueriedLanguageNames = left.queriedLanguageNames == right.queriedLanguageNames
            let sameNavigationTitle = left.navigationTitle == right.navigationTitle
            let sameNoResultsLabelText = left.noResultsLabelText == right.noResultsLabelText
            let sameSearchQuery = left.searchQuery == right.searchQuery
            let sameSelectedLanguageCode = left.selectedLanguageCode == right.selectedLanguageCode

            guard sameCancelHeaderItemText,
                  sameDoneHeaderItemText,
                  sameIsPresented,
                  sameIsDoneHeaderItemEnabled,
                  sameLocalizedLanguageNames,
                  sameQueriedLanguageNames,
                  sameNavigationTitle,
                  sameNoResultsLabelText,
                  sameSearchQuery,
                  sameSelectedLanguageCode else { return false }

            return true
        }
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.cancelHeaderItemTapped):
            state.isPresented.wrappedValue = false

        case .action(.doneHeaderItemTapped):
            state.isPresented.wrappedValue = false
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
        }

        return .none
    }
}
