//
//  AppConstants+StatusIndicatorButton.swift
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
    enum StatusIndicatorButton {
        public static let imageFrameHeight: CGFloat = 30
        public static let imageFrameWidth: CGFloat = 30

        public static let imageTrailingPadding: CGFloat = 3
        public static let labelFontSize: CGFloat = 15
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum StatusIndicatorButton {
        public static let deniedStatusImageSecondaryForeground: Color = .red
        public static let grantedStatusImageSecondaryForeground: Color = .green // swiftlint:disable:next identifier_name
        public static let undeterminedStatusImageSecondaryForeground: Color = .orange

        public static let determinedStatusLabelForeground: Color = .gray
        public static let undeterminedStatusLabelForeground: Color = .white

        public static let foreground: Color = .blue
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum StatusIndicatorButton {
        public static let deniedStatusImageSystemName = "x.circle.fill"
        public static let grantedStatusImageSystemName = "checkmark.circle.fill"
        public static let undeterminedStatusImageSystemName = "questionmark.circle.fill"
    }
}
