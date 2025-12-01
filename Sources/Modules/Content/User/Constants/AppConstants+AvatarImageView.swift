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

extension AppConstants.CGFloats {
    enum AvatarImageView {
        static let badgeViewCornerRadius: CGFloat = 8
        static let badgeViewLabelSystemFontSize: CGFloat = 14
        static let badgeViewShadowRadius: CGFloat = 20

        static let badgeViewHeight: CGFloat = 20
        static let badgeViewWidth: CGFloat = 20

        static let badgeViewOffsetX: CGFloat = 15
        static let badgeViewOffsetY: CGFloat = 15

        static let cornerRadius: CGFloat = 10

        static let frameHeight: CGFloat = 50
        static let frameWidth: CGFloat = 50

        static let systemFontSize: CGFloat = 50
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum AvatarImageView {
        static let badgeViewDarkForeground: Color = .init(uiColor: .init(hex: 0x27252A))
        static let badgeViewLightForeground: Color = .init(uiColor: .init(hex: 0xE5E5EA))

        static let badgeViewLabelShadow: Color = .init(uiColor: .black)
        static let imageForeground: Color = .gray
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum AvatarImageView {
        static let badgeImageSystemName = "person.2.circle.fill"
        static let defaultImageSystemName = "person.crop.circle.fill"
    }
}
