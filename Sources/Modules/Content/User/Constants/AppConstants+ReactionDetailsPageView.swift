//
//  AppConstants+ReactionDetailsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ReactionDetailsPageView {
        static let groupListViewHorizontalPadding: CGFloat = 20
        static let groupListViewTopPadding: CGFloat = 20
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ReactionDetailsPageView {
        static let doneHeaderItemForeground: Color = UIApplication.isGlassTintingEnabled ? .white : .navigationBarButton
        static let navigationBarItemGlassTint: Color = .init(uiColor: .accentOrSystemBlue)
    }
}
