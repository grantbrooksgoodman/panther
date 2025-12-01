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

extension AppConstants.CGFloats {
    enum PenPalsPermissionPageView {
        static let dismissButtonBottomPadding: CGFloat = 70

        static let enableButtonBottomPadding: CGFloat = 20

        static let enableButtonLabelCornerRadius: CGFloat = 16
        static let enableButtonLabelFrameHeight: CGFloat = 50
        static let enableButtonLabelFrameMinWidth: CGFloat = 200
        static let enableButtonLabelHorizontalPadding: CGFloat = 40

        static let enableButtonLabelShadowColorOpacity: CGFloat = 0.2
        static let enableButtonLabelShadowRadius: CGFloat = 10
        static let enableButtonLabelShadowYOffset: CGFloat = 4

        static let subtitleLabelHorizontalPadding: CGFloat = 20
        static let subtitleLabelTopPadding: CGFloat = 25

        static let titleLabelBottomPadding: CGFloat = 20
        static let titleLabelFontScale: CGFloat = 34
        static let titleLabelTopPadding: CGFloat = 60
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum PenPalsPermissionPageView {
        static let accent: Color = .init(uiColor: .accentOrSystemBlue)
        static let enableButtonLabelOverlayTextForeground: Color = .white
        static let enableButtonLabelShadow: Color = .black
    }
}
