//
//  ChangeLanguagePageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum ChangeLanguagePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case confirmButtonText = "Confirm" // swiftlint:disable:next line_length
        case instructionViewSubtitleLabelText = "This will change the language in which you send and receive messages, as well as the language of system dialogues.\n\nMessages you have already received in your current language will not be re-translated retroactively. The app must be restarted for this to take effect."
        case instructionViewTitleLabelText = "Select Language"
        case navigationTitle = "Change Language"

        // MARK: - Properties

        var alternate: String? {
            nil
        }
    }
}

enum ChangeLanguagePageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.ChangeLanguagePageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .changeLanguagePageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
