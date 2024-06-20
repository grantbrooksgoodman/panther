//
//  AppConstants+ContactDetailView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ContactDetailView {
        public static let avatarImageViewTrailingPadding: CGFloat = 2
        public static let cornerRadius: CGFloat = 8
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ContactDetailView {
        public static let darkBackground: Color = .init(uiColor: UIColor(hex: 0x2A2A2C))
        public static let lightBackground: Color = .white
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ContactDetailView {
        public static let chevronImageSystemName = "chevron.forward"
    }
}
