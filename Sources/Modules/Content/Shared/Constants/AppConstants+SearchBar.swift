//
//  AppConstants+SearchBar.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum SearchBar {
        static let clearButtonImageOpacity: CGFloat = 1

        static let defaultBottomPadding: CGFloat = 8

        static let glassEffectPadding: CGFloat = 4

        static let innerHStackCornerRadius: CGFloat = 10
        static let innerHStackHorizontalPadding: CGFloat = 8

        static let textFieldFrameHeight: CGFloat = 36
        static let textFieldMinimumScaleFactor: CGFloat = 0.5

        static let v26HorizontalPadding: CGFloat = 15
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum SearchBar {
        static let clearButtonImageForeground: Color = .secondary
        static let searchImageForeground: Color = .secondary

        static let innerHStackDarkBackground: Color = .init(uiColor: .init(hex: 0x3B3A3F))
        static let innerHStackLightBackground: Color = .init(uiColor: .init(hex: 0xE7E7E9))
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum SearchBar {
        static let clearButtonImageSystemName = "xmark.circle.fill"
        static let searchImageSystemName = "magnifyingglass"
    }
}
