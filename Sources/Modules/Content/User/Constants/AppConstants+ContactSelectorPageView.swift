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

public extension AppConstants.CGFloats {
    enum ContactSelectorPageView {
        public static let cancelToolbarButtonSystemFontSize: CGFloat = 17
        public static let listViewDefaultMinListRowHeight: CGFloat = 44
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ContactSelectorPageView {
        public static let noResultsLabelForeground: Color = .init(uiColor: .secondaryLabel)
    }
}
