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

extension AppConstants.CGFloats {
    enum MediaItemView {
        static let imageCornerRadius: CGFloat = 8
        static let imageFrameHeight: CGFloat = 60
        static let imageFrameWidth: CGFloat = 60
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum MediaItemView {
        static let senderLabelForeground: Color = .init(uiColor: .systemGray)
        static let timestampLabelForeground: Color = .init(uiColor: .systemGray)
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum MediaItemView {
        static let saveActionImageSystemName = "square.and.arrow.down"
    }
}
