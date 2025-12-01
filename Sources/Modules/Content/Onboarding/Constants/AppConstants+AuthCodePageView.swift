//
//  AppConstants+AuthCodePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum AuthCodePageView {
        static let backButtonLabelFontSize: CGFloat = 15
        static let backButtonTopPadding: CGFloat = 2

        static let continueButtonTopPadding: CGFloat = 10

        static let innerVStackBottomPadding: CGFloat = 50
        static let instructionLabelVerticalPadding: CGFloat = 5

        static let textFieldHorizontalPadding: CGFloat = 20
        static let textFieldVerticalPadding: CGFloat = 2
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum AuthCodePageView {
        static let instructionLabelForeground: Color = .gray
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum AuthCodePageView {
        static let textFieldPlaceholder = "000000"
    }
}
