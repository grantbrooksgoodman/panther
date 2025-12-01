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

extension AppConstants.CGFloats {
    enum ReactionsViewController {
        static let reactionButtonHeight: CGFloat = 35
        static let reactionButtonTitleLabelSystemFontSize: CGFloat = 15
        static let stackViewLeadingAnchorConstraintConstant: CGFloat = 10
        static let stackViewSpacing: CGFloat = 8
        static let subviewLayerCornerRadius: CGFloat = 17.5
        static let superviewLayerCornerRadius: CGFloat = 5
        static let viewAlpha: CGFloat = 0.8
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ReactionsViewController { // NIT: Using UIColor for this.
        static let reactionButtonBackground: UIColor = .systemGray3
    }
}
