//
//  AppConstants+RegionMenu.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum RegionMenu {
        static let buttonLabelGlassEffectPadding: CGFloat = 3

        static let buttonLabelImageCornerRadius: CGFloat = 3
        static let buttonLabelImageFrameHeight: CGFloat = 25
        static let buttonLabelImageFrameWidth: CGFloat = 40

        // swiftlint:disable:next identifier_name
        static let buttonLabelVStackBackgroundRectangleCornerRadius: CGFloat = 6
        static let buttonLabelVStackShadowRadius: CGFloat = 2

        static let buttonLabelVStackFrameMinHeight: CGFloat = 80
        static let buttonLabelVStackFrameMinWidth: CGFloat = 45

        static let delayMilliseconds: CGFloat = 500
        static let secondaryDelayMilliseconds: CGFloat = 200

        static let headerLabelFrameMaxHeight: CGFloat = 54
        static let headerLabelSystemFontSize: CGFloat = 17

        static let listViewCellLabelImageCornerRadius: CGFloat = 3
        static let listViewCellLabelImageFrameHeight: CGFloat = 25
        static let listViewCellLabelImageFrameWidth: CGFloat = 40

        static let selectedCellImageLeadingPadding: CGFloat = 3
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum RegionMenu {
        static let buttonLabelDarkForeground: Color = .init(uiColor: .init(hex: 0x2A2A2C))
        static let buttonLabelLightForeground: Color = .white
        static let buttonLabelTextForeground: Color = .init(uiColor: .systemBlue)

        static let noResultsLabelTextForeground: Color = .init(uiColor: .secondaryLabel)
        static let selectedCellImageForeground: Color = .green
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum RegionMenu {
        static let selectedCellImageSystemName = "checkmark.circle.fill"
    }
}
