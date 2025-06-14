//
//  AppConstants+SettingsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum SettingsPageView {
        public static let buildInfoButtonImageBottomPadding: CGFloat = 2

        public static let buildInfoButtonImageFrameHeight: CGFloat = (515 / 20)
        public static let buildInfoButtonImageFrameWidth: CGFloat = (1000 / 20)

        public static let buildInfoButtonLabelBottomPadding: CGFloat = 8

        public static let contactDetailViewBottomPadding: CGFloat = 20
        public static let contactDetailViewHorizontalPadding: CGFloat = 20
        public static let contactDetailViewTopPadding: CGFloat = 30

        public static let deleteAccountOverlayAlpha: CGFloat = 0.5
        public static let signOutNavigationDelayMilliseconds: CGFloat = 500

        public static let groupedListViewBottomPadding: CGFloat = 20
        public static let groupedListViewHorizontalPadding: CGFloat = 20

        // swiftlint:disable identifier_name
        public static let changeThemeButtonOverlayFramePercentOfTotalSize: CGFloat = 0.75
        public static let clearCachesButtonOverlayFramePercentOfTotalSize: CGFloat = 0.6
        public static let toggleDeveloperModeButtonOverlayFramePercentOfTotalSize: CGFloat = 0.6
        // swiftlint:enable identifier_name
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SettingsPageView {
        public static let blockedUsersButtonImageBackground: Color = .init(uiColor: .systemGray)
        public static let changeThemeButtonImageBackground: Color = .purple
        public static let clearCachesButtonImageBackground: Color = .mint
        public static let deleteAccountButtonImageBackground: Color = .orange
        public static let inviteFriendsButtonImageBackground: Color = .blue
        public static let leaveReviewButtonImageBackground: Color = .yellow // swiftlint:disable:next identifier_name
        public static let messageRecipientConsentButtonImageBackground: Color = .green // swiftlint:disable:next identifier_name
        public static let overrideLanguageCodeButtonImageBackground: Color = .mint
        public static let sendFeedbackButtonImageBackground: Color = .green
        public static let signOutButtonImageBackground: Color = .red
        public static let toggleDeveloperModeButtonImageBackground: Color = .yellow
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum SettingsPageView {
        // swiftlint:disable:next identifier_name
        public static let buildInfoButtonDarkBackgroundImageSystemName = "NT (White).png" // swiftlint:disable:next identifier_name
        public static let buildInfoButtonLightBackgroundImageSystemName = "NT (Black).png"

        public static let blockedUsersButtonImageSystemName = "flag.fill"
        public static let changeThemeButtonImageSystemName = "eye.fill"
        public static let clearCachesButtonImageSystemName = "command"
        public static let deleteAccountButtonImageSystemName = "trash.fill"
        public static let doneToolbarButtonImageSystemName = "checkmark"
        public static let inviteFriendsButtonImageSystemName = "location.fill"
        public static let leaveReviewButtonImageSystemName = "star.fill" // swiftlint:disable:next identifier_name
        public static let messageRecipientConsentButtonImageSystemName = "shield.pattern.checkered" // swiftlint:disable:next identifier_name
        public static let overrideLanguageCodeButtonImageSystemName = "square.text.square.fill"
        public static let sendFeedbackButtonImageSystemName = "info"
        public static let signOutButtonImageSystemName = "hand.raised.fill"
        public static let toggleDeveloperModeButtonImageSystemName = "command"

        public static let overrideLanguageCodeButtonText = "Override Language Code to English"
        public static let restoreLanguageCodeButtonTextPrefix = "Restore Language to"
        public static let toggleDeveloperModeButtonText = "Toggle Developer Mode"

        public static let reviewOnAppStoreURLString = "https://apps.apple.com/app/id1662674065?action=write-review"
    }
}
