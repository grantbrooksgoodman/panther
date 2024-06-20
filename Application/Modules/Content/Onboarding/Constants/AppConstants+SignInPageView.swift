//
//  AppConstants+SignInPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum SignInPageView {
        public static let backButtonLabelFontSize: CGFloat = 15

        public static let backButtonTopPadding: CGFloat = 2
        public static let continueButtonTopPadding: CGFloat = 5

        public static let imageBottomPadding: CGFloat = 5
        public static let imageFrameHeight: CGFloat = 70
        public static let imageFrameWidth: CGFloat = 150

        public static let instructionLabelHorizontalPadding: CGFloat = 30
        public static let instructionLabelVerticalPadding: CGFloat = 5

        public static let phoneNumberTextFieldTrailingPadding: CGFloat = 20
        public static let phoneNumberTextFieldVerticalPadding: CGFloat = 2

        public static let regionMenuLeadingPadding: CGFloat = 20
        public static let regionMenuTrailingPadding: CGFloat = 5

        public static let textFieldHorizontalPadding: CGFloat = 20
        public static let textFieldVerticalPadding: CGFloat = 2
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SignInPageView {
        public static let imageDarkForeground: Color = .init(uiColor: .init(hex: 0xF8F8F8))
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum SignInPageView {
        public static let textFieldPlaceholder = "000000"
    }
}
