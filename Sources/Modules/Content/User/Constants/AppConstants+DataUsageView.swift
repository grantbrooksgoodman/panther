//
//  AppConstants+DataUsageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/01/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum DataUsageView {
        static let defaultUsageLimit: CGFloat = 10240
        static let labelBottomPadding: CGFloat = 5
        static let lowUsageThreshold: CGFloat = 0.3
        static let mediumUsageThreshold: CGFloat = 0.6
        static let percentLabelFractionMultiplier: CGFloat = 100
        static let usageInMegabytesDivisor: CGFloat = 1024
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum DataUsageView {
        static let highUsage: Color = .init(uiColor: .systemRed)
        static let lowUsage: Color = .init(uiColor: .systemBlue)

        static var mediumUsage: Color {
            .init(
                uiColor: ThemeService.isDarkModeActive ? .systemYellow : .systemOrange
            )
        }
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum DataUsageView {
        static let defaultLabelText = "Data used"
        static let zero = "0.00"
    }
}
