//
//  AppConstants+SplashPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum SplashPageView {
        public static let fadeInDelayMilliseconds: CGFloat = 250

        public static let imageFrameHeight: CGFloat = 70
        public static let imageFrameWidth: CGFloat = 150

        public static let padding: CGFloat = 5
        public static let progressViewScaleEffect: CGFloat = 0.8

        public static let rebuildingIndicesLabelAnimationOpacity: CGFloat = 0.3
        public static let rebuildingIndicesLabelFontSize: CGFloat = 14
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SplashPageView {
        public static let imageDarkForeground: Color = .init(uiColor: .init(hex: 0xF8F8F8))
    }
}
