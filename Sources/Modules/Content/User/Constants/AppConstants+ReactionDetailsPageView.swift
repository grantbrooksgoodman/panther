//
//  AppConstants+ReactionDetailsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ReactionDetailsPageView {
        public static let groupListViewHorizontalPadding: CGFloat = 20
        public static let groupListViewTopPadding: CGFloat = 20
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ReactionDetailsPageView {
        public static let doneHeaderItemForeground: Color = UIApplication.isGlassTintingEnabled ? .white : .navigationBarButton
        public static let navigationBarItemGlassTint: Color = ThemeService.isAppDefaultThemeApplied ? .init(uiColor: .systemBlue) : .accent
    }
}
