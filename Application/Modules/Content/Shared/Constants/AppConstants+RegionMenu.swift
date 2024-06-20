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

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum RegionMenu {
        public static let buttonLabelImageCornerRadius: CGFloat = 3
        public static let buttonLabelImageFrameHeight: CGFloat = 25
        public static let buttonLabelImageFrameWidth: CGFloat = 40

        // swiftlint:disable:next identifier_name
        public static let buttonLabelVStackBackgroundRectangleCornerRadius: CGFloat = 6
        public static let buttonLabelVStackShadowRadius: CGFloat = 2

        public static let buttonLabelVStackFrameMinHeight: CGFloat = 80
        public static let buttonLabelVStackFrameMinWidth: CGFloat = 45

        public static let dismissDelayMilliseconds: CGFloat = 500

        public static let headerLabelFrameMaxHeight: CGFloat = 54
        public static let headerLabelSystemFontSize: CGFloat = 17

        public static let listViewCellLabelImageCornerRadius: CGFloat = 3
        public static let listViewCellLabelImageFrameHeight: CGFloat = 25
        public static let listViewCellLabelImageFrameWidth: CGFloat = 40

        public static let selectedCellImageLeadingPadding: CGFloat = 3
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum RegionMenu {
        public static let buttonLabelDarkForeground: Color = .init(uiColor: .init(hex: 0x2A2A2C))
        public static let buttonLabelLightForeground: Color = .white
        public static let buttonLabelTextForeground: Color = .init(uiColor: .systemBlue)

        public static let noResultsLabelTextForeground: Color = .init(uiColor: .secondaryLabel)
        public static let selectedCellImageForeground: Color = .green
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum RegionMenu {
        public static let selectedCellImageSystemName = "checkmark.circle.fill"
    }
}
