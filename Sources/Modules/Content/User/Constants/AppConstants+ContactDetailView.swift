//
//  AppConstants+ContactDetailView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ContactDetailView {
        static let avatarImageViewTrailingPadding: CGFloat = 2
        static let chevronImageFrameMaxHeight: CGFloat = 15
        static let chevronImageFrameMaxWidth: CGFloat = 15
        static let cornerRadius: CGFloat = 8
        static let glassEffectPadding: CGFloat = 4
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ContactDetailView {
        static let darkBackground: Color = .init(uiColor: UIColor(hex: 0x2A2A2C))
        static let lightBackground: Color = .white
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ContactDetailView {
        static let chevronImageSystemName = "chevron.forward"
    }
}
