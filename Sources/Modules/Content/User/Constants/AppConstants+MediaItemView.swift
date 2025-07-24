//
//  AppConstants+MediaItemView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum MediaItemView {
        public static let imageCornerRadius: CGFloat = 8
        public static let imageFrameHeight: CGFloat = 60
        public static let imageFrameWidth: CGFloat = 60
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum MediaItemView {
        public static let senderLabelForegrround: Color = .init(uiColor: .systemGray)
        public static let timestampLabelForeground: Color = .init(uiColor: .systemGray)
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum MediaItemView {
        public static let saveActionImageSystemName = "square.and.arrow.down"
    }
}
