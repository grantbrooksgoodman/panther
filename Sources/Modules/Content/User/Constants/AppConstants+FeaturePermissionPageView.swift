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
        /* MARK: Properties */

        static let animationDuration: CGFloat = 0.35

        static let dismissButtonBottomPadding: CGFloat = 70

        static let enableButtonBottomPadding: CGFloat = 20
        static let enableButtonLabelCornerRadius: CGFloat = 16
        static let enableButtonLabelFrameHeight: CGFloat = 50
        static let enableButtonLabelFrameMinWidth: CGFloat = 200
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
        static let titleLabelMinimumScaleFactor: CGFloat = 0.5
        static let titleLabelTopPadding: CGFloat = 60

        /* MARK: Computed Properties */

        @MainActor
        static var enableButtonLabelHorizontalPadding: CGFloat {
            UIApplication.isFullyV26Compatible ? 50 : 40
        }
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum FeaturePermissionPageView {
        /* MARK: Properties */

        static let enableButtonLabelOverlayTextForeground: Color = .white
        static let enableButtonLabelShadow: Color = .black

        static let lightBackground: Color = .white

        /* MARK: Computed Properties */

        @MainActor
        static var accent: Color {
            .init(uiColor: .accentOrSystemBlue)
        }
    }
}
