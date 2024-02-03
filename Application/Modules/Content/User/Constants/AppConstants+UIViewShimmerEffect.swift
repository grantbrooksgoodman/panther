//
//  AppConstants+UIViewShimmerEffect.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum UIViewShimmerEffect {
        public static let animationDuration: CGFloat = 1.5

        public static let animationPrimaryToValue: CGFloat = 0.8
        public static let animationSecondaryFromValue: CGFloat = 0.1
        public static let animationSecondaryToValue: CGFloat = 0.9
        public static let animationTertiaryFromValue: CGFloat = 0.2

        public static let gradientLayerEndPointY: CGFloat = 0.525
        public static let gradientLayerStartPointY: CGFloat = 0.5

        public static let gradientLayerFrameWidthMultiplier: CGFloat = 3

        public static let gradientLayerPrimaryLocation: CGFloat = 0.4
        public static let gradientLayerSecondaryLocation: CGFloat = 0.5
        public static let gradientLayerTertiaryLocation: CGFloat = 0.6
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum UIViewShimmerEffect {
        public static let dark: Color = .init(uiColor: .black)
        public static let light: Color = .init(uiColor: .init(red: 0, green: 0, blue: 0, alpha: 0.1))
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum UIViewShimmerEffect {
        public static let animationKeyPath = "locations"
        public static let gradientLayerAnimationKey = "shimmer"
    }
}
