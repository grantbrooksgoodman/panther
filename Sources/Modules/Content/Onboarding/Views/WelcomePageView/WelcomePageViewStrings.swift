//
//  WelcomePageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum WelcomePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case continueButtonText = "Get Started"
        case signInButtonText = "Sign In"

        // MARK: - Properties

        var alternate: String? {
            switch self {
            case .continueButtonText: "Create an Account"
            default: nil
            }
        }
    }
}

enum WelcomePageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
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
