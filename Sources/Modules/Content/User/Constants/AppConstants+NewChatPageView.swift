//
//  AppConstants+NewChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 20/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum NewChatPageView {
        public static let doneToolbarButtonFrameHeight: CGFloat = 30
        public static let doneToolbarButtonFrameWidth: CGFloat = 30

        public static let navigationBarHeightIncrement: CGFloat = 20

        public static let penPalsToolbarButtonFrameHeight: CGFloat = 30
        public static let penPalsToolbarButtonFrameWidth: CGFloat = 30
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum NewChatPageView {
        public static let navigationBarItemGlassTint: Color = ThemeService.isAppDefaultThemeApplied ? .init(uiColor: .systemBlue) : .accent
        public static let tintedGlassToolbarButtonForeground: Color = .white
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum NewChatPageView {
        public static let cancelToolbarButtonImageSystemName = "xmark"
        public static let doneToolbarButtonImageSystemName = "checkmark"
    }
}
