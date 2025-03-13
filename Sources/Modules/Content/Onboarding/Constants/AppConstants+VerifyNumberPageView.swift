//
//  AppConstants+VerifyNumberPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum VerifyNumberPageView {
        public static let backButtonLabelFontSize: CGFloat = 15
        public static let backButtonTopPadding: CGFloat = 2

        public static let bottomPadding: CGFloat = 30
        public static let continueButtonTopPadding: CGFloat = 5

        public static let instructionLabelVerticalPadding: CGFloat = 5

        public static let phoneNumberTextFieldTrailingPadding: CGFloat = 20
        public static let phoneNumberTextFieldVerticalPadding: CGFloat = 2

        public static let regionMenuLeadingPadding: CGFloat = 20
        public static let regionMenuTrailingPadding: CGFloat = 5
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum VerifyNumberPageView {
        public static let instructionLabelForeground: Color = .gray
    }
}
