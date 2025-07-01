//
//  AppConstants+InstructionView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum InstructionView {
        public static let frameHeight: CGFloat = 200
        public static let leadingPadding: CGFloat = 20
        public static let screenWidthDivisor: CGFloat = 2

        public static let subtitleLabelFontSize: CGFloat = 14
        public static let subtitleLabelMinimumScaleFactor: CGFloat = 0.01

        public static let titleLabelBottomPadding: CGFloat = 2
        public static let titleLabelMinimumScaleFactor: CGFloat = 0.01

        public static let topPadding: CGFloat = 15
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum InstructionView {
        public static let subtitleLabelForeground: Color = .gray
    }
}
