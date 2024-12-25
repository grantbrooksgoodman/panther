//
//  AppConstants+ListRowView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 24/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ListRowView {
        public static let chevronImageFrameMaxHeight: CGFloat = 14
        public static let chevronImageFrameMaxWidth: CGFloat = 14

        // swiftlint:disable identifier_name
        public static let clipShapeRoundedRectangleCornerSizeFrameHeight: CGFloat = 8
        public static let clipShapeRoundedRectangleCornerSizeFrameWidth: CGFloat = 8
        // swiftlint:enable identifier_name

        public static let imageCornerRadius: CGFloat = 7
        public static let imageFrameHeight: CGFloat = 30
        public static let imageFrameWidth: CGFloat = 30
        public static let imageLeadingPadding: CGFloat = 3

        public static let titleLabelLeadingPadding: CGFloat = 5
        public static let verticalPadding: CGFloat = 8
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ListRowView {
        public static let darkBackground: Color = .init(uiColor: .init(hex: 0x2A2A2C))
        public static let lightBackground: Color = .white
        public static let titleLabelDisabledForeground: Color = .gray
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ListRowView {
        public static let chevronImageSystemName = "chevron.forward"
    }
}
