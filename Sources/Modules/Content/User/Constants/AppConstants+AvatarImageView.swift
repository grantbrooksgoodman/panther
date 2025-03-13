//
//  AppConstants+AvatarImageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum AvatarImageView {
        public static let badgeViewCornerRadius: CGFloat = 8
        public static let badgeViewLabelSystemFontSize: CGFloat = 14
        public static let badgeViewShadowRadius: CGFloat = 20

        public static let badgeViewHeight: CGFloat = 20
        public static let badgeViewWidth: CGFloat = 20

        public static let badgeViewOffsetX: CGFloat = 15
        public static let badgeViewOffsetY: CGFloat = 15

        public static let cornerRadius: CGFloat = 10

        public static let frameHeight: CGFloat = 50
        public static let frameWidth: CGFloat = 50

        public static let systemFontSize: CGFloat = 50
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum AvatarImageView {
        public static let badgeViewDarkForeground: Color = .init(uiColor: .init(hex: 0x27252A))
        public static let badgeViewLightForeground: Color = .init(uiColor: .init(hex: 0xE5E5EA))

        public static let badgeViewLabelShadow: Color = .init(uiColor: .black)
        public static let imageForeground: Color = .gray
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum AvatarImageView {
        public static let badgeImageSystemName = "person.2.circle.fill"
        public static let defaultImageSystemName = "person.crop.circle.fill"
    }
}
