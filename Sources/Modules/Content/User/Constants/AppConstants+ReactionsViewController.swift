//
//  AppConstants+ReactionsViewController.swift
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
    enum ReactionsViewController {
        public static let reactionButtonHeight: CGFloat = 35
        public static let reactionButtonTitleLabelSystemFontSize: CGFloat = 15
        public static let stackViewLeadingAnchorConstraintConstant: CGFloat = 10
        public static let stackViewSpacing: CGFloat = 8
        public static let subviewLayerCornerRadius: CGFloat = 17.5
        public static let superviewLayerCornerRadius: CGFloat = 5
        public static let viewAlpha: CGFloat = 0.8
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ReactionsViewController { // NIT: Using UIColor for this.
        public static let reactionButtonBackground: UIColor = .systemGray3
    }
}
