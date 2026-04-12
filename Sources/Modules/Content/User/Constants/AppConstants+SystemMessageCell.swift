//
//  AppConstants+SystemMessageCell.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum SystemMessageCell {
        static let activityStringSystemFontSize: CGFloat = 12
        static let additionalVerticalPadding: CGFloat = 10
        static let defaultHeight: CGFloat = 44
        static let labelMinimumScaleFactor: CGFloat = 0.9
        static let labelNumberOfLines: CGFloat = 3
        static let labelParagraphStyleLineSpacing: CGFloat = 4
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum SystemMessageCell { // NIT: Using UIColor for this.
        @MainActor
        static var activityStringForeground: UIColor {
            ThemeService.isDarkModeActive ? UIColor.lightGray : .systemGray
        }
    }
}
