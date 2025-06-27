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

/* Proprietary */
import AppSubsystem

// MARK: - Color

public extension AppConstants.Colors {
    enum InviteLanguagePickerView {
        public static let doneHeaderItemForeground: Color = UIApplication.isGlassTintingEnabled ? .white : .navigationBarButton
        public static let navigationBarItemGlassTint: Color = ThemeService.isAppDefaultThemeApplied ? .init(uiColor: .systemBlue) : .accent
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
