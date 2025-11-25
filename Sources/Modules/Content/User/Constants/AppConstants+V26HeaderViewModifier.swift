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

public extension AppConstants.CGFloats {
    enum V26HeaderViewModifier {
        public static let imageMaxWidthDivisor: CGFloat = 3
        public static let navigationBarHeightIncrement: CGFloat = 20
        public static let toolbarButtonHeight: CGFloat = 30
        public static let toolbarButtonWidth: CGFloat = 30
        public static let toolbarButtonLabelHorizontalPadding: CGFloat = 8
        public static let toolbarButtonLabelMinimumScaleFactor: CGFloat = 0.5
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum V26HeaderViewModifier {
        public static let cancelToolbarButtonImageSystemName = "xmark"
        public static let doneToolbarButtonImageSystemName = "checkmark"
    }
}
