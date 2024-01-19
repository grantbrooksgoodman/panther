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

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum UserInfoBadgeView {
        public static let bodyCornerRadius: CGFloat = 3
        public static let bodyMaxHeight: CGFloat = 20
        public static let bodyMaxWidth: CGFloat = 50

        public static let labelViewHStackSpacing: CGFloat = 2

        public static let labelViewImageCornerRadius: CGFloat = 2
        public static let labelViewImageFrameHeight: CGFloat = 10
        public static let labelViewImageFrameWidth: CGFloat = 20

        public static let labelViewTextFrameHeight: CGFloat = 10
        public static let labelViewTextFrameWidth: CGFloat = 20

        public static let labelViewTextOpacity: CGFloat = 0.8
        public static let labelViewTextShadowRadius: CGFloat = 20
        public static let labelViewTextSystemFontSize: CGFloat = 13
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum UserInfoBadgeView {
        public static let bodyDarkForeground: Color = .init(uiColor: .init(hex: 0x27252A))
        public static let bodyLightForeground: Color = .init(uiColor: .init(hex: 0xE5E5EA))
        public static let labelViewTextShadow: Color = .black
    }
}
