//
//  AppConstants+StaticListView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum StaticListView {
        // swiftlint:disable:next identifier_name
        public static let clipShapeRoundedRectangleCornerSizeHeight: CGFloat = 8
        public static let clipShapeRoundedRectangleCornerSizeWidth: CGFloat = 8

        public static let frameMaxHeightPrimaryMultiplier: CGFloat = 33.8
        public static let frameMaxHeightSecondaryMultiplier: CGFloat = 10

        public static let imageCornerRadius: CGFloat = 7
        public static let imageFrameHeight: CGFloat = 30
        public static let imageFrameWidth: CGFloat = 30

        public static let labelLeadingPadding: CGFloat = 5
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum StaticListView {
        public static let cellViewDefaultDarkBackground: Color = .init(uiColor: .init(hex: 0x2A2A2C))
        public static let cellViewSelectedDarkBackground: Color = .init(uiColor: .init(hex: 0x3A3A3C))
    }
}
