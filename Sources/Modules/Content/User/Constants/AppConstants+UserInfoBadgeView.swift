//
//  AppConstants+UserInfoBadgeView.swift
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
    enum UserInfoBadgeView {
        static let bodyCornerRadius: CGFloat = 3
        static let bodyMaxHeight: CGFloat = 20
        static let bodyMaxWidth: CGFloat = 50

        static let labelViewHStackSpacing: CGFloat = 2

        static let labelViewImageCornerRadius: CGFloat = 2
        static let labelViewImageFrameHeight: CGFloat = 10
        static let labelViewImageFrameWidth: CGFloat = 20

        static let labelViewTextFrameHeight: CGFloat = 10
        static let labelViewTextFrameWidth: CGFloat = 20

        static let labelViewTextOpacity: CGFloat = 0.8
        static let labelViewTextShadowRadius: CGFloat = 20
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum UserInfoBadgeView {
        static let bodyDarkForeground: Color = .init(uiColor: .init(hex: 0x27252A))
        static let bodyLightForeground: Color = .init(uiColor: .init(hex: 0xE5E5EA))
        static let labelViewTextShadow: Color = .black
    }
}
