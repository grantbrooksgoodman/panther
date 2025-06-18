//
//  AppConstants+PenPalsPermissionPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum PenPalsPermissionPageView {
        public static let dismissButtonBottomPadding: CGFloat = 70

        public static let enableButtonBottomPadding: CGFloat = 20

        public static let enableButtonLabelCornerRadius: CGFloat = 16
        public static let enableButtonLabelFrameHeight: CGFloat = 50
        public static let enableButtonLabelFrameMinWidth: CGFloat = 200
        public static let enableButtonLabelHorizontalPadding: CGFloat = 40

        public static let enableButtonLabelShadowColorOpacity: CGFloat = 0.2
        public static let enableButtonLabelShadowRadius: CGFloat = 10
        public static let enableButtonLabelShadowYOffset: CGFloat = 4

        public static let subtitleLabelHorizontalPadding: CGFloat = 20
        public static let subtitleLabelTopPadding: CGFloat = 25

        public static let titleLabelBottomPadding: CGFloat = 20
        public static let titleLabelFontScale: CGFloat = 34
        public static let titleLabelTopPadding: CGFloat = 60
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum PenPalsPermissionPageView {
        public static let accent: Color = ThemeService.isAppDefaultThemeApplied ? .init(uiColor: .systemBlue) : .accent
        public static let enableButtonLabelOverlayTextForeground: Color = .white
        public static let enableButtonLabelShadow: Color = .black
    }
}
