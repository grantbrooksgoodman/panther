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

        public static let staticListViewBottomPadding: CGFloat = 20
        public static let staticListViewHorizontalPadding: CGFloat = 20
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SettingsPageView {
        public static let blockedUsersButtonImageForeground: Color = .init(uiColor: .systemGray)
        public static let changeThemeButtonImageForeground: Color = .purple
        public static let clearCachesButtonImageForeground: Color = .mint
        public static let deleteAccountButtonImageForeground: Color = .orange
        public static let inviteFriendsButtonImageForeground: Color = .blue
        public static let leaveReviewButtonImageForeground: Color = .yellow // swiftlint:disable:next identifier_name
        public static let overrideLanguageCodeButtonImageForeground: Color = .mint
        public static let sendFeedbackButtonImageForeground: Color = .green
        public static let signOutButtonImageForeground: Color = .red
        public static let toggleDeveloperModeButtonImageForeground: Color = .yellow
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum SettingsPageView {
        // swiftlint:disable:next identifier_name
        public static let buildInfoButtonDarkBackgroundImageSystemName = "NT (White).png" // swiftlint:disable:next identifier_name
        public static let buildInfoButtonLightBackgroundImageSystemName = "NT (Black).png"

        public static let blockedUsersButtonImageSystemName = "flag.square.fill"
        public static let changeThemeButtonImageSystemName = "eye.square.fill"
        public static let clearCachesButtonImageSystemName = "command.square.fill"
        public static let deleteAccountButtonImageSystemName = "trash.square.fill"
        public static let inviteFriendsButtonImageSystemName = "location.square.fill"
        public static let leaveReviewButtonImageSystemName = "star.square.fill" // swiftlint:disable:next identifier_name
        public static let overrideLanguageCodeButtonImageSystemName = "square.text.square.fill"
        public static let sendFeedbackButtonImageSystemName = "info.square.fill"
        public static let signOutButtonImageSystemName = "hand.raised.square.fill"
        public static let toggleDeveloperModeButtonImageSystemName = "command.square.fill"

        public static let overrideLanguageCodeButtonText = "Override Language Code to English"
        public static let restoreLanguageCodeButtonTextPrefix = "Restore Language to"
        public static let toggleDeveloperModeButtonText = "Toggle Developer Mode"

        public static let reviewOnAppStoreURLString = "https://apps.apple.com/app/id1662674065?action=write-review"
    }
}
