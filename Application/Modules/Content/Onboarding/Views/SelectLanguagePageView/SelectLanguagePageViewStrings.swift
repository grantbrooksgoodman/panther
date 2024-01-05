//
//  SelectLanguagePageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

public extension TranslatedLabelStringCollection {
    enum SelectLanguagePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case backButtonText = "Back"
        case continueButtonText = "Continue"

        case instructionLabelText = "I speak:"
        case instructionViewSubtitleLabelText = "To begin, please select your language.\n\nNote that this setting cannot be changed later."
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
