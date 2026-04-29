//
//  AppConstants+ChatPageHeaderView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/04/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ChatPageHeaderView {
        /* MARK: Properties */

        static let avatarImageSize: CGFloat = 54
        static let avatarImageViewBadgeCountComparator: CGFloat = 2 // swiftlint:disable:next identifier_name
        static let avatarViewNameLabelChevronSymbolFrameSize: CGFloat = 12
        static let avatarViewNameLabelFontSize: CGFloat = 16
        static let avatarViewNameLabelGlassEffectPadding: CGFloat = 8
        static let avatarViewNameLabelSpacing: CGFloat = 2
        static let avatarViewNameLabelTextHorizontalPadding: CGFloat = 1.5
        static let avatarViewNameLabelViewHorizontalPadding: CGFloat = 30
        static let avatarViewSpacing: CGFloat = -4

        static let backButtonFrameSize: CGFloat = 30
        static let backButtonGlassEffectPadding: CGFloat = 8
        static let backButtonSymbolFrameSize: CGFloat = 18
        static let backButtonViewHorizontalPadding: CGFloat = 16
        static let backgroundViewHeightIncrement: CGFloat = 28

        static let contentViewVerticalPadding: CGFloat = 4

        /* MARK: Computed Properties */

        @MainActor
        static var backgroundViewBlurOpacity: CGFloat {
            ThemeService.isDarkModeActive ? 0.6 : 0.7
        }
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ChatPageHeaderView {
        static let avatarImageViewBackground: Color = .init(uiColor: .systemBackground) // swiftlint:disable:next identifier_name
        static let avatarViewNameLabelChevronSymbolForeground: Color = .init(uiColor: .systemGray2)
        static let backgroundViewGradientColor: Color = .black
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatPageHeaderView { // swiftlint:disable:next identifier_name
        static let avatarViewNameLabelChevronSymbolImageSystemName = "chevron.compact.right"
        static let backButtonImageSystemName = "chevron.backward"
    }
}
