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

public extension TranslatedLabelStringCollection {
    enum SettingsPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case blockedUsersButtonText = "Blocked Users"
        case changeThemeButtonText = "Change Theme"
        case clearCachesButtonText = "Clear Caches"
        case deleteAccountButtonText = "Delete Account"
        case inviteFriendsButtonText = "Invite Friends"
        case leaveReviewButtonText = "Leave a Review"
        case penPalsListRowInnerText = "Participate in ⌘PenPals⌘" // swiftlint:disable:next line_length
        case penPalsListRowFooterText = "⌘PenPals⌘ enables cross-cultural communication, allowing users to connect fluently with a randomly-selected person at any time."
        case signOutButtonText = "Sign Out"

        // MARK: - Properties

        public var alternate: String? {
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

public enum SettingsPageViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
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
