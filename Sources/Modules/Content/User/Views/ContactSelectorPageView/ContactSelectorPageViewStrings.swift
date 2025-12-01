//
//  ContactSelectorPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum ContactSelectorPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case navigationTitle = "Add to Conversation"
        case noResultsLabelText = "No contacts found.\nTap to search for users with this phone number."
        case searchBarPlaceholderText = "Search contacts or enter phone number"

        // MARK: - Properties

        var alternate: String? { nil }
    }
}

enum ContactSelectorPageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.ContactSelectorPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .contactSelectorPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
