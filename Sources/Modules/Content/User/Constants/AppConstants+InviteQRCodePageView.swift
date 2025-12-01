//
//  AppConstants+InviteQRCodePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum InviteQRCodePageView {
        static let imageBottomPadding: CGFloat = 50
        static let imageHorizontalPadding: CGFloat = 10
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum InviteQRCodePageView {
        static let navigationBarItemGlassTint: Color = .init(uiColor: .accentOrSystemBlue)
        static let tintedGlassToolbarButtonForeground: Color = .white
    }
}
