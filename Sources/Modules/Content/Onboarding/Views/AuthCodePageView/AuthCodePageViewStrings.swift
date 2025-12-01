//
//  AuthCodePageViewStrings.swift
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
    enum AuthCodePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case backButtonText = "Back"
        case continueButtonText = "Continue"

        case instructionLabelText = "Enter the code sent to your device:"
        case instructionViewSubtitleLabelText = "A verification code was sent to your device. It may take a minute or so to arrive."
        case instructionViewTitleLabelText = "Enter Verification Code"

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

enum AuthCodePageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.AuthCodePageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .authCodePageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
