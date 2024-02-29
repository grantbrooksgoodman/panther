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

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum SearchBar {
        public static let clearButtonImageOpacity: CGFloat = 1
        public static let defaultBottomPadding: CGFloat = 8

        public static let innerHStackCornerRadius: CGFloat = 10
        public static let innerHStackHorizontalPadding: CGFloat = 8

        public static let textFieldFrameHeight: CGFloat = 36
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum SearchBar {
        public static let clearButtonImageForeground: Color = .secondary
        public static let searchImageForeground: Color = .secondary

        public static let innerHStackDarkBackground: Color = .init(uiColor: .init(hex: 0x3B3A3F))
        public static let innerHStackLightBackground: Color = .init(uiColor: .init(hex: 0xE7E7E9))
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum SearchBar {
        public static let clearButtonImageSystemName = "xmark.circle.fill"
        public static let searchImageSystemName = "magnifyingglass"
    }
}
