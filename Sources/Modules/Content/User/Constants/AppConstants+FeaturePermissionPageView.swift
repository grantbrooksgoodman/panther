//
//  AppConstants+FeaturePermissionPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum FeaturePermissionPageView {
        static let animationDuration: CGFloat = 0.35

        static let dismissButtonBottomPadding: CGFloat = 70

        static let enableButtonBottomPadding: CGFloat = 20
        static let enableButtonLabelCornerRadius: CGFloat = 16
        static let enableButtonLabelFrameHeight: CGFloat = 50
        static let enableButtonLabelFrameMinWidth: CGFloat = 200
        static let enableButtonLabelHorizontalPadding: CGFloat = UIApplication.isFullyV26Compatible ? 50 : 40
        static let enableButtonLabelShadowColorOpacity: CGFloat = 0.2
        static let enableButtonLabelShadowRadius: CGFloat = 10
        static let enableButtonLabelShadowYOffset: CGFloat = 4

        static let labelHorizontalPadding: CGFloat = 20

        static let pageIndicatorBottomPadding: CGFloat = 10
        static let pageIndicatorCircleSelectedOpacity: CGFloat = 0.25
        static let pageIndicatorCircleSize: CGFloat = 7
        static let pageIndicatorHStackSpacing: CGFloat = 8

        static let subtitleLabelTopPadding: CGFloat = 25

        static let titleLabelBottomPadding: CGFloat = 20
        static let titleLabelFontScale: CGFloat = 34
        static let titleLabelTopPadding: CGFloat = 60
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum FeaturePermissionPageView {
        static let accent: Color = .init(uiColor: .accentOrSystemBlue)

        static let enableButtonLabelOverlayTextForeground: Color = .white
        static let enableButtonLabelShadow: Color = .black

        static let lightBackground: Color = .white
    }
}
