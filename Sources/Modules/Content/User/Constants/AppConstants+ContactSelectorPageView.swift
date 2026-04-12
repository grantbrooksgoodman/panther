//
//  AppConstants+ContactSelectorPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 26/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ContactSelectorPageView {
        static let cancelToolbarButtonSystemFontSize: CGFloat = 17
        static let listViewDefaultMinListRowHeight: CGFloat = 44
        static let noResultsLabelHorizontalPadding: CGFloat = 10
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ContactSelectorPageView {
        /* MARK: Properties */

        static let noResultsLabelAlternateForeground: Color = .init(uiColor: .systemBlue)
        static let noResultsLabelForeground: Color = .init(uiColor: .secondaryLabel)
        static let tintedGlassToolbarButtonForeground: Color = .white

        /* MARK: Computed Properties */

        @MainActor
        static var navigationBarItemGlassTint: Color {
            .init(uiColor: .accentOrSystemBlue)
        }
    }
}
