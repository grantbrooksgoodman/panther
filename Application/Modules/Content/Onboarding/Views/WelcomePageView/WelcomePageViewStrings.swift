//
//  WelcomePageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension TranslatedLabelStringCollection {
    enum WelcomePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case instructionLabelText = "Welcome to *Hello*. Follow the short instructions to get started."
        case continueButtonText = "Continue"
        case signInButtonText = "I already use this app"

        // MARK: - Properties

        public var alternate: String? { nil }
    }
}

public enum WelcomePageViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.WelcomePageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .welcomePageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
