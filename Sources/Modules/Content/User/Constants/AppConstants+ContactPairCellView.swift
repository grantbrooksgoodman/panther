//
//  AppConstants+ContactPairCellView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ContactPairCellView {
        static let hStackSpacing: CGFloat = 3.5
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ContactPairCellView {
        static let prevaricationModeBackground: Color = .init(uiColor: .init(hex: 0xF3EDE6))
    }
}
