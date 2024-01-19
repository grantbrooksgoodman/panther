//
//  AppConstants+AvatarImageView.swift
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
    enum AvatarImageView {
        public static let cornerRadius: CGFloat = 10

        public static let frameHeight: CGFloat = 50
        public static let frameWidth: CGFloat = 50

        public static let systemFontSize: CGFloat = 50
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum AvatarImageView {
        public static let defaultImageForeground: Color = .gray
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum AvatarImageView {
        public static let defaultImageSystemName = "person.crop.circle.fill"
    }
}
