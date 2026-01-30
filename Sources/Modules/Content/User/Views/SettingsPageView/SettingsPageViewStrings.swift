//
//  SettingsPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum SettingsPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        // swiftlint:disable:next line_length
        case aiEnhanceTranslationsListRowFooterText = "Allow translations to be AI-enhanced for clarity without changing meaning. The content of your messages may be sent through an LLM."
        case aiEnhanceTranslationsListRowInnerText = "AI-enhanced translations"
        case blockedUsersButtonText = "Blocked Users"
        case changeLanguage = "Change Language"
        case changeThemeButtonText = "Change Theme"
        case clearCachesButtonText = "Clear Caches"
        case dataUsageLabelText = "Data usage"
        case deleteAccountButtonText = "Delete Account"
        case inviteFriendsButtonText = "Invite Friends"
        case leaveReviewButtonText = "Leave a Review" // swiftlint:disable:next line_length
        case penPalsListRowFooterText = "⌘PenPals⌘ enables cross-cultural communication, allowing users to connect fluently with a randomly-selected person at any time."
        case penPalsListRowInnerText = "Participate in ⌘PenPals⌘"
        case recipientConsentListRowFooterText = "Require consent from recipients to receive messages from your account."
        case recipientConsentListRowInnerText = "Require recipient consent"
        case signOutButtonText = "Sign Out"

        // MARK: - Properties

        var alternate: String? {
            switch self {
            case .changeThemeButtonText:
                return "Change Appearance"

            case .leaveReviewButtonText:
                return "Rate the App"

            case .signOutButtonText:
                return "Log Out"

            default:
                return nil
            }
        }
    }
}

enum SettingsPageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.SettingsPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .settingsPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
