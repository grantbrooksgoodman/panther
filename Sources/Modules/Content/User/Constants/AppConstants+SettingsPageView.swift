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

extension AppConstants.CGFloats {
    enum SettingsPageView {
        static let buildInfoButtonImageBottomPadding: CGFloat = 2

        static let buildInfoButtonImageFrameHeight: CGFloat = (515 / 20)
        static let buildInfoButtonImageFrameWidth: CGFloat = (1000 / 20)

        static let buildInfoButtonLabelBottomPadding: CGFloat = 8

        static let contactDetailViewBottomPadding: CGFloat = 20
        static let contactDetailViewHorizontalPadding: CGFloat = 20
        static let contactDetailViewTopPadding: CGFloat = 30

        static let signOutNavigationDelayMilliseconds: CGFloat = 500

        static let groupedListViewBottomPadding: CGFloat = 20
        static let groupedListViewHorizontalPadding: CGFloat = UIApplication.isFullyV26Compatible ? 25 : 20

        // swiftlint:disable identifier_name
        static let changeLanguageButtonOverlayFramePercentOfTotalSize: CGFloat = 0.7
        static let changeThemeButtonOverlayFramePercentOfTotalSize: CGFloat = 0.75
        static let clearCachesButtonOverlayFramePercentOfTotalSize: CGFloat = 0.6
        static let toggleDeveloperModeButtonOverlayFramePercentOfTotalSize: CGFloat = 0.6
        // swiftlint:enable identifier_name
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum SettingsPageView {
        static let blockedUsersButtonImageBackground: Color = .init(uiColor: .systemGray)
        static let changeLanguageButtonImageBackground: Color = .pink
        static let changeLanguageButtonImageForeground: Color = .white
        static let changeThemeButtonImageBackground: Color = .green
        static let clearCachesButtonImageBackground: Color = .mint
        static let deleteAccountButtonImageBackground: Color = .orange
        static let inviteFriendsButtonImageBackground: Color = .blue
        static let leaveReviewButtonImageBackground: Color = .yellow // swiftlint:disable:next identifier_name
        static let messageRecipientConsentButtonImageBackground: Color = .green // swiftlint:disable:next identifier_name
        static let overrideLanguageCodeButtonImageBackground: Color = .mint
        static let sendFeedbackButtonImageBackground: Color = .indigo
        static let signOutButtonImageBackground: Color = .red
        static let toggleDeveloperModeButtonImageBackground: Color = .yellow
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum SettingsPageView {
        // swiftlint:disable:next identifier_name
        static let buildInfoButtonDarkBackgroundImageSystemName = "NT (White).png" // swiftlint:disable:next identifier_name
        static let buildInfoButtonLightBackgroundImageSystemName = "NT (Black).png"

        static let blockedUsersButtonImageSystemName = "flag.fill"
        static let changeThemeButtonImageSystemName = "eye.fill"
        static let clearCachesButtonImageSystemName = "command"
        static let deleteAccountButtonImageSystemName = "trash.fill"
        static let inviteFriendsButtonImageSystemName = "location.fill"
        static let leaveReviewButtonImageSystemName = "star.fill" // swiftlint:disable:next identifier_name
        static let messageRecipientConsentButtonImageSystemName = "shield.pattern.checkered" // swiftlint:disable:next identifier_name
        static let overrideLanguageCodeButtonImageSystemName = "square.text.square.fill"
        static let sendFeedbackButtonImageSystemName = "info"
        static let signOutButtonImageSystemName = "hand.raised.fill"
        static let toggleDeveloperModeButtonImageSystemName = "command"

        static let overrideLanguageCodeButtonText = "Override Language Code to English"
        static let restoreLanguageCodeButtonTextPrefix = "Restore Language to"
        static let toggleDeveloperModeButtonText = "Toggle Developer Mode"

        static let reviewOnAppStoreURLString = "https://apps.apple.com/app/id1662674065?action=write-review"
    }
}
