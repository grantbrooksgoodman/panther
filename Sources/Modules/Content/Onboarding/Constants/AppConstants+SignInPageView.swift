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

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum SignInPageView {
        static let backButtonLabelFontSize: CGFloat = 15

        static let backButtonTopPadding: CGFloat = 2
        static let continueButtonTopPadding: CGFloat = 5

        static let imageBottomPadding: CGFloat = 5
        static let imageFrameHeight: CGFloat = 70
        static let imageFrameWidth: CGFloat = 150

        static let instructionLabelHorizontalPadding: CGFloat = 30
        static let instructionLabelVerticalPadding: CGFloat = 5

        static let phoneNumberTextFieldTrailingPadding: CGFloat = 20
        static let phoneNumberTextFieldVerticalPadding: CGFloat = 2

        static let regionMenuLeadingPadding: CGFloat = 20
        static let regionMenuTrailingPadding: CGFloat = 5

        static let textFieldHorizontalPadding: CGFloat = 20
        static let textFieldVerticalPadding: CGFloat = 2
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum SignInPageView {
        static let imageDarkForeground: Color = .init(uiColor: .init(hex: 0xF8F8F8))
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum SignInPageView {
        static let textFieldPlaceholder = "000000"
    }
}
