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

extension AppConstants.CGFloats {
    enum SquareIconView {
        static let cornerRadius: CGFloat = 30

        static let defaultFrameHeight: CGFloat = 150
        static let defaultFrameWidth: CGFloat = 150

        static let overlayFrameHeightMultiplier: CGFloat = 2 / 3
        static let overlayFrameWidthMultiplier: CGFloat = 2 / 3
        static let overlayTextFontScale: CGFloat = 60

        static let shadowColorOpacity: CGFloat = 0.2
        static let shadowRadius: CGFloat = 10
        static let shadowYOffset: CGFloat = 5
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum SquareIconView {
        static let overlaySymbolForeground: Color = .white
        static let shadow: Color = .black
    }
}
