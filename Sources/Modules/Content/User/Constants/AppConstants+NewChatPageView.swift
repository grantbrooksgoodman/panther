//
//  AppConstants+NewChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 20/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum NewChatPageView {
        static let doneToolbarButtonFrameHeight: CGFloat = 30
        static let doneToolbarButtonFrameWidth: CGFloat = 30

        static let navigationBarHeightIncrement: CGFloat = 20

        static let penPalsToolbarButtonFrameHeight: CGFloat = 30
        static let penPalsToolbarButtonFrameWidth: CGFloat = 30
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum NewChatPageView {
        /* MARK: Properties */

        static let tintedGlassToolbarButtonForeground: Color = .white

        /* MARK: Computed Properties */

        @MainActor
        static var navigationBarItemGlassTint: Color {
            .init(uiColor: .accentOrSystemBlue)
        }
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum NewChatPageView {
        static let cancelToolbarButtonImageSystemName = "xmark"
        static let doneToolbarButtonImageSystemName = "checkmark"
    }
}
