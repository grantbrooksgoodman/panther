//
//  ConversationsPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum ConversationsPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case navigationTitle = "Messages"
        case prevaricationModeNavigationTitle = "Conversations"

        // MARK: - Properties

        var alternate: String? {
            nil
        }
    }
}

enum ConversationsPageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.ConversationsPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .conversationsPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
