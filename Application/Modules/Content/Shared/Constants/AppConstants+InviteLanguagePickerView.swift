//
//  AppConstants+InviteLanguagePickerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum InviteLanguagePickerView {
        public static let cellLabelSystemFontSize: CGFloat = 17
        public static let noResultsLabelSystemFontSize: CGFloat = 18
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum InviteLanguagePickerView {
        public static let noResultsLabelForeground: Color = .init(uiColor: .secondaryLabel)
        public static let selectedCellImageForeground: Color = .green
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum InviteLanguagePickerView {
        public static let selectedCellImageSystemName = "checkmark.circle.fill"
    }
}
