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

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum SelectLanguagePageView {
        public static let backButtonLabelFontSize: CGFloat = 15
        public static let backButtonTopPadding: CGFloat = 2

        public static let continueButtonTopPadding: CGFloat = 5
        public static let instructionLabelVerticalPadding: CGFloat = 5

        public static let pickerHorizontalPadding: CGFloat = 30
        public static let topPadding: CGFloat = 50
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SelectLanguagePageView {
//        public static let backButtonForeground: Color = .blue
//        public static let continueButtonForeground: Color = .blue
        public static let instructionLabelForeground: Color = .gray
    }
}
