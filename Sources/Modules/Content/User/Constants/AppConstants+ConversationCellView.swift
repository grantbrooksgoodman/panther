//
//  AppConstants+ConversationCellView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ConversationCellView {
        static let avatarImageViewTopPadding: CGFloat = 10

        static let chevronImageAndDateLabelHStackSpacing: CGFloat = 0 // swiftlint:disable:next identifier_name
        static let chevronImageForegroundColorAdjustmentPercentage: CGFloat = 75
        static let chevronImageFrameMaxWidth: CGFloat = 12
        static let chevronImageFrameMaxHeight: CGFloat = 12

        static let dateLabelPaddingTrailing: CGFloat = 6
        static let dateLabelSystemFontSize: CGFloat = 14

        static let frameHeight: CGFloat = 62

        static let navigationLinkFrameWidth: CGFloat = 0
        static let navigationLinkOpacity: CGFloat = 0

        // swiftlint:disable:next identifier_name
        static let subtitleLabelForegroundColorAdjustmentPercentage: CGFloat = 3
        static let subtitleLabelLineLimit: CGFloat = 2
        static let subtitleLabelSystemFontSize: CGFloat = 14
        static let subtitleLabelXOffset: CGFloat = 1.5
        static let subtitleLabelYOffset: CGFloat = -3

        static let titleLabelBottomPadding: CGFloat = 0.01
        static let titleLabelMinimumScaleFactor: CGFloat = 0.01
        static let titleLabelSystemFontSize: CGFloat = 500

        static let unreadIndicatorViewFrameHeight: CGFloat = 10
        static let unreadIndicatorViewFrameWidth: CGFloat = 10
        static let unreadIndicatorViewTrailingPadding: CGFloat = -15
        static let unreadIndicatorViewXOffset: CGFloat = -10
        static let unreadIndicatorViewYOffset: CGFloat = 7
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ConversationCellView {
        static let blockUsersButtonImageTint: Color = .init(uiColor: .systemGray)
        static let deleteConversationButtonImageTint: Color = .red
        static let reportUsersButtonImageTint: Color = .orange
        static let unreadIndicatorViewForeground: Color = .blue
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ConversationCellView {
        static let blockUsersButtonImageSystemName = "flag"
        static let chevronImageSystemName = "chevron.forward"
        static let deleteConversationButtonImageSystemName = "trash"
        static let reportUsersButtonImageSystemName = "exclamationmark.bubble"
    }
}
