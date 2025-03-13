//
//  AppConstants+SquareIconView.swift
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
    enum SquareIconView {
        public static let cornerRadius: CGFloat = 30

        public static let defaultFrameHeight: CGFloat = 150
        public static let defaultFrameWidth: CGFloat = 150

        public static let overlayFrameHeightMultiplier: CGFloat = 2 / 3
        public static let overlayFrameWidthMultiplier: CGFloat = 2 / 3

        public static let shadowColorOpacity: CGFloat = 0.2
        public static let shadowRadius: CGFloat = 10
        public static let shadowYOffset: CGFloat = 5
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SquareIconView {
        public static let overlaySymbolForeground: Color = .white
        public static let shadow: Color = .black
    }
}
