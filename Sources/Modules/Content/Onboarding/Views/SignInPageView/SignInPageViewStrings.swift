//
//  SignInPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum SignInPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case backButtonText = "Back"
        case phoneNumberContinueButtonText = "Continue"
        case verificationCodeContinueButtonText = "Finish"

        case phoneNumberInstructionLabelText = "Enter your phone number below:"
        case verificationCodeInstructionLabelText = "Enter the code sent to your device:"

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

enum SignInPageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.SignInPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .signInPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
