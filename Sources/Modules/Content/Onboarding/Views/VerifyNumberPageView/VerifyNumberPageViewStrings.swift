//
//  VerifyNumberPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum VerifyNumberPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case backButtonText = "Back"
        case continueButtonText = "Continue"

        case instructionLabelText = "Enter your phone number below:"
        case instructionViewTitleLabelText = "Enter Phone Number" // swiftlint:disable:next line_length
        case instructionViewSubtitleLabelText = "Next, enter your phone number.\n\nA verification code will be sent to your number. Standard messaging rates apply."

        // MARK: - Properties

        var alternate: String? {
            switch self {
            case .backButtonText:
                return "Go back"

            default:
                return nil
            }
        }
    }
}

enum VerifyNumberPageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.VerifyNumberPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .verifyNumberPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
