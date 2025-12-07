//
//  PenPalsPermissionPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum PenPalsPermissionPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case dismissButtonText = "Not Now"
        case enableButtonText = "Enable"

        // swiftlint:disable:next line_length
        case subtitleLabelText = "⌘PenPals⌘ enables cross-cultural communication between users of different languages.\n\nEnabling this feature allows you to connect fluently with a randomly-selected person at any time. In turn, your account will be entered into the pool of available ⌘PenPals⌘ for other people to connect with.\n\n⌘PenPals⌘ cannot view each other’s phone numbers unless explicitly allowed. Your participation in ⌘PenPals⌘ can be toggled at any time via Settings."
        case titleLabelText = "Introducing ⌘PenPals⌘"

        // MARK: - Properties

        var alternate: String? {
            switch self {
            case .subtitleLabelText: // swiftlint:disable:next line_length
                "⌘PenPals⌘ enables cross-cultural communication between speakers of different languages.\n\nEnabling this feature allows you to connect fluently with a randomly-selected person at any time. In turn, your account will be entered into the pool of available ⌘PenPals⌘ for other people to connect with.\n\n⌘PenPals⌘ cannot view each other’s phone numbers unless explicitly allowed. Your participation in ⌘PenPals⌘ can be toggled at any time via Settings."
            default: nil
            }
        }
    }
}

enum PenPalsPermissionPageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.PenPalsPermissionPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .penPalsPermissionPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
