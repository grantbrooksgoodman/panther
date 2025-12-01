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

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum StatusIndicatorButton {
        static let imageFrameHeight: CGFloat = 30
        static let imageFrameWidth: CGFloat = 30

        static let imageTrailingPadding: CGFloat = 3
        static let labelFontSize: CGFloat = 15
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum StatusIndicatorButton {
        static let deniedStatusImageSecondaryForeground: Color = .red
        static let grantedStatusImageSecondaryForeground: Color = .green // swiftlint:disable:next identifier_name
        static let undeterminedStatusImageSecondaryForeground: Color = .orange

        static let determinedStatusLabelForeground: Color = .gray
        static let undeterminedStatusLabelForeground: Color = .white

        static let foreground: Color = .blue
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum StatusIndicatorButton {
        static let deniedStatusImageSystemName = "x.circle.fill"
        static let grantedStatusImageSystemName = "checkmark.circle.fill"
        static let undeterminedStatusImageSystemName = "questionmark.circle.fill"
    }
}
