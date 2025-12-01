//
//  AppConstants+SelectLanguagePageView.swift
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
    enum SelectLanguagePageView {
        static let backButtonLabelFontSize: CGFloat = 15
        static let backButtonTopPadding: CGFloat = 2

        static let continueButtonTopPadding: CGFloat = 5

        static let innerVStackBottomPadding: CGFloat = 50
        static let instructionLabelVerticalPadding: CGFloat = 5

        static let pickerHorizontalPadding: CGFloat = 30
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum SelectLanguagePageView {
        static let instructionLabelForeground: Color = .gray
    }
}
