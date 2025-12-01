//
//  AppConstants+V26HeaderViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum V26HeaderViewModifier {
        static let imageMaxWidthDivisor: CGFloat = 3
        static let navigationBarHeightIncrement: CGFloat = 20
        static let toolbarButtonHeight: CGFloat = 30
        static let toolbarButtonWidth: CGFloat = 30
        static let toolbarButtonLabelHorizontalPadding: CGFloat = 8
        static let toolbarButtonLabelMinimumScaleFactor: CGFloat = 0.5
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum V26HeaderViewModifier {
        static let cancelToolbarButtonImageSystemName = "xmark"
        static let doneToolbarButtonImageSystemName = "checkmark"
    }
}
