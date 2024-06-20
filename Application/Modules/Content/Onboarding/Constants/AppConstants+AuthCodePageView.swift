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

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum AuthCodePageView {
        public static let backButtonLabelFontSize: CGFloat = 15
        public static let backButtonTopPadding: CGFloat = 2

        public static let bottomPadding: CGFloat = 30
        public static let continueButtonTopPadding: CGFloat = 10

        public static let instructionLabelVerticalPadding: CGFloat = 5

        public static let textFieldHorizontalPadding: CGFloat = 20
        public static let textFieldVerticalPadding: CGFloat = 2
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum AuthCodePageView {
        public static let instructionLabelForeground: Color = .gray
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum AuthCodePageView {
        public static let textFieldPlaceholder = "000000"
    }
}
