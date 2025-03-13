//
//  AppConstants+ChatInfoPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ChatInfoPageView {
        public static let addContactButtonCircleFrameMaxHeight: CGFloat = 40
        public static let addContactButtonCircleFrameMaxWidth: CGFloat = 40
        public static let addContactButtonCircleTrailingPadding: CGFloat = 2

        public static let addContactButtonImageHeight: CGFloat = 15
        public static let addContactButtonImageWidth: CGFloat = 15

        public static let avatarImageViewHorizontalPadding: CGFloat = 10
        public static let avatarImageViewTopPadding: CGFloat = 20

        public static let changeMetadataButtonHorizontalPadding: CGFloat = 10
        public static let changeMetadataButtonLabelFontSize: CGFloat = 15

        public static let chatInfoCellSubtitleLabelFontSize: CGFloat = 15
        public static let chatTitleLabelHorizontalPadding: CGFloat = 10

        public static let largeAvatarImageViewSizeHeight: CGFloat = 100
        public static let largeAvatarImageViewSizeWidth: CGFloat = 100

        public static let listViewYOffset: CGFloat = -8

        public static let penPalsListRowViewHorizontalPadding: CGFloat = 30
        public static let penPalsListRowViewTopPadding: CGFloat = 5

        public static let smallAvatarImageViewSizeHeight: CGFloat = 40
        public static let smallAvatarImageViewSizeWidth: CGFloat = 40
        public static let smallAvatarImageViewTrailingPadding: CGFloat = 2

        public static let singleCNContactViewYOffset: CGFloat = -7.5
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ChatInfoPageView {
        public static let addContactButtonCircleDarkForeground: Color = .init(uiColor: .init(hex: 0x3A3A3C))
        public static let addContactButtonCircleLightForeground: Color = .init(uiColor: .init(hex: 0xE5E5EA))
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ChatInfoPageView {
        public static let addContactButtonImageSystemName = "plus"
    }
}
