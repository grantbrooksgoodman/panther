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

extension AppConstants.Colors {
    enum InviteLanguagePickerView {
        static let doneHeaderItemForeground: Color = UIApplication.isGlassTintingEnabled ? .white : .navigationBarButton
        static let navigationBarItemGlassTint: Color = .init(uiColor: .accentOrSystemBlue)
        static let noResultsLabelForeground: Color = .init(uiColor: .secondaryLabel)
        static let selectedCellImageForeground: Color = .green
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum InviteLanguagePickerView {
        static let selectedCellImageSystemName = "checkmark.circle.fill"
    }
}
