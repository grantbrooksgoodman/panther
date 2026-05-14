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
        case blockedUsersButtonText = "Blocked users"
        case changeLanguage = "Change language"
        case changeThemeButtonText = "Change theme"
        case clearCachesButtonText = "Clear caches"
        case dataUsageLabelText = "Data usage"
        case deleteAccountButtonText = "Delete account"
        case inviteFriendsButtonText = "Invite friends"
        case leaveReviewButtonText = "Leave a review" // swiftlint:disable:next line_length
        case penPalsListRowFooterText = "⌘PenPals⌘ enables cross-cultural communication, allowing users to connect fluently with a randomly-selected person at any time."
        case penPalsListRowInnerText = "Participate in ⌘PenPals⌘"
        case recipientConsentListRowFooterText = "Require consent from recipients to receive messages from your account."
        case recipientConsentListRowInnerText = "Require recipient consent"
        case signOutButtonText = "Sign out"

        // MARK: - Properties

        var alternate: String? {
            switch self {
            case .changeThemeButtonText:
                "Change appearance"

            case .leaveReviewButtonText:
                "Rate the app"

            case .recipientConsentListRowInnerText:
                "Require recipient consent"

            case .signOutButtonText:
                "Log out"

            default:
                nil
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
