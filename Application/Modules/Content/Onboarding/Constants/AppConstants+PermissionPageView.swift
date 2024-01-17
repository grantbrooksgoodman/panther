//
//  AppConstants+PermissionPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum PermissionsView {
        public static let backButtonFontSize: CGFloat = 15
        public static let backButtonTopPadding: CGFloat = 2

        public static let buttonVStackBottomPadding: CGFloat = 80
        public static let buttonVStackTopPadding: CGFloat = 80

        public static let finishButtonTopPadding: CGFloat = 5
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum PermissionsView {
        public static let backButtonForeground: Color = .blue
        public static let finishButtonAccent: Color = .blue
    }
}
