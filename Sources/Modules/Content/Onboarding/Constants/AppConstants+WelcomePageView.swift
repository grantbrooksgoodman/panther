//
//  AppConstants+WelcomePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum WelcomePageView {
        static let continueButtonVerticalPadding: CGFloat = 5

        static let imageBottomPadding: CGFloat = 5
        static let imageFrameHeight: CGFloat = 70
        static let imageFrameWidth: CGFloat = 150
        static let instructionLabelHorizontalPadding: CGFloat = 30
        static let instructionLabelVerticalPadding: CGFloat = 5

        static let signInButtonLabelFontSize: CGFloat = 15
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum WelcomePageView {
        static let imageDarkForeground: Color = .init(uiColor: .init(hex: 0xF8F8F8))
    }
}
