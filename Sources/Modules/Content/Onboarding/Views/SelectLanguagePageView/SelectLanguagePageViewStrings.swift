//
//  SelectLanguagePageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

public extension TranslatedLabelStringCollection {
    enum SelectLanguagePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case backButtonText = "Back"
        case continueButtonText = "Continue"

        case instructionLabelText = "I speak:" // swiftlint:disable:next line_length
        case instructionViewSubtitleLabelText = "To begin, please select your language.\n\nThis will be the language you send and receive messages in, as well as that of system dialogues. Your selection can be changed later in Settings."
        case instructionViewTitleLabelText = "Select Language"

        // MARK: - Properties

        public var alternate: String? {
            switch self {
            case .backButtonText:
                return "Go back"

            default:
                return nil
            }
        }
    }
}

public enum SelectLanguagePageViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.SelectLanguagePageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .selectLanguagePageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
