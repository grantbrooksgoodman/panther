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

public extension AppConstants.CGFloats {
    enum SystemMessageCell {
        public static let activityStringSystemFontSize: CGFloat = 12
        public static let labelMinimumScaleFactor: CGFloat = 0.1
        public static let labelNumberOfLines: CGFloat = 2
        public static let labelParagraphStyleLineSpacing: CGFloat = 4
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SystemMessageCell { // NIT: Using UIColor for this.
        public static let activityStringForeground: UIColor = ThemeService.isDarkModeActive ? UIColor.lightGray : .gray
    }
}
