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

extension AppConstants.CGFloats {
    enum VerifyNumberPageView {
        static let backButtonLabelFontSize: CGFloat = 15
        static let backButtonTopPadding: CGFloat = 2

        static let bottomPadding: CGFloat = 30
        static let continueButtonTopPadding: CGFloat = 5

        static let innerVStackBottomPadding: CGFloat = 50
        static let instructionLabelVerticalPadding: CGFloat = 5

        static let phoneNumberTextFieldTrailingPadding: CGFloat = 20
        static let phoneNumberTextFieldVerticalPadding: CGFloat = 2

        static let regionMenuLeadingPadding: CGFloat = 20
        static let regionMenuTrailingPadding: CGFloat = 5
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum VerifyNumberPageView {
        static let instructionLabelForeground: Color = .gray
    }
}
