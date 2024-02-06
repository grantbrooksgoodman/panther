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

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum WelcomePageView {
        public static let continueButtonVerticalPadding: CGFloat = 5
        public static let signInButtonVerticalPadding: CGFloat = 5

        public static let imageBottomPadding: CGFloat = 5
        public static let imageFrameHeight: CGFloat = 70
        public static let imageFrameWidth: CGFloat = 150

        public static let instructionLabelHorizontalPadding: CGFloat = 30
        public static let instructionLabelVerticalPadding: CGFloat = 5
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum WelcomePageView {
        public static let continueButtonForeground: Color = .blue
        public static let imageDarkForeground: Color = .init(uiColor: .init(hex: 0xF8F8F8))
        public static let signInButtonForeground: Color = .blue
    }
}
