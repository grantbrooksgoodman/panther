//
//  AppConstants+SplashPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum SplashPageView {
        static let activityIndicatorScaleEffect: CGFloat = 0.8

        static let fadeInDelayMilliseconds: CGFloat = 250

        static let imageFrameHeight: CGFloat = 70
        static let imageFrameWidth: CGFloat = 150

        static let padding: CGFloat = 5

        // swiftlint:disable:next identifier_name
        static let progressBarActivityIndicatorFrameMaxHeight: CGFloat = 30 // swiftlint:disable:next identifier_name
        static let progressBarActivityIndicatorFrameMaxWidth: CGFloat = 30

        static let progressBarHorizontalPadding: CGFloat = 40
        static let progressBarTopPadding: CGFloat = 10
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum SplashPageView {
        /* MARK: Properties */

        static let imageDarkForeground: Color = .init(uiColor: .init(hex: 0xF8F8F8))
        static let progressBarActivityIndicatorTint: Color = .init(uiColor: .systemGray)

        /* MARK: Computed Properties */

        @MainActor
        static var loadingLabelForeground: Color {
            .init(uiColor: ThemeService.isDarkModeActive ? .lightGray : .darkGray)
        }

        @MainActor
        static var progressBarTint: Color {
            .init(uiColor: .accentOrSystemBlue)
        }
    }
}
