//
//  ConversationsPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension TranslatedLabelStringCollection {
    enum ConversationsPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case navigationTitle = "Messages"

        // MARK: - Properties

        public var alternate: String? { nil }
    }
}

public enum ConversationsPageViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
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
