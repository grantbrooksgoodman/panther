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

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ConversationCellView {
        public static let avatarImageViewTopPadding: CGFloat = 10

        public static let chevronImageAndDateLabelHStackSpacing: CGFloat = 0 // swiftlint:disable:next identifier_name
        public static let chevronImageForegroundColorAdjustmentPercentage: CGFloat = 60
        public static let chevronImageSystemFontSize: CGFloat = 14

        public static let dateLabelPaddingTrailing: CGFloat = 6
        public static let dateLabelSystemFontSize: CGFloat = 14

        public static let frameHeight: CGFloat = 62

        public static let navigationLinkFrameWidth: CGFloat = 0
        public static let navigationLinkOpacity: CGFloat = 0

        // swiftlint:disable:next identifier_name
        public static let subtitleLabelForegroundColorAdjustmentPercentage: CGFloat = 3
        public static let subtitleLabelLineLimit: CGFloat = 2
        public static let subtitleLabelSystemFontSize: CGFloat = 14
        public static let subtitleLabelXOffset: CGFloat = 1.5
        public static let subtitleLabelYOffset: CGFloat = -3

        public static let titleLabelBottomPadding: CGFloat = 0.01
        public static let titleLabelMinimumScaleFactor: CGFloat = 0.01
        public static let titleLabelSystemFontSize: CGFloat = 500

        public static let unreadIndicatorViewFrameHeight: CGFloat = 10
        public static let unreadIndicatorViewFrameWidth: CGFloat = 10
        public static let unreadIndicatorViewTrailingPadding: CGFloat = -15
        public static let unreadIndicatorViewXOffset: CGFloat = -10
        public static let unreadIndicatorViewYOffset: CGFloat = 7
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ConversationCellView {
        public static let deleteConversationButtonImageTint: Color = .red
        public static let unreadIndicatorViewForeground: Color = .blue
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ConversationCellView {
        public static let chatInfoButtonImageSystemName = "info.circle"
        public static let chevronImageSystemName = "chevron.forward"
        public static let deleteConversationButtonImageSystemName = "trash"
    }
}
