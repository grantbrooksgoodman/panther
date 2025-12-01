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

extension AppConstants.CGFloats {
    enum InstructionView {
        static let frameMaxHeight: CGFloat = 220
        static let leadingPadding: CGFloat = 20
        static let screenWidthDivisor: CGFloat = 2

        static let subtitleLabelFontSize: CGFloat = 14
        static let subtitleLabelMinimumScaleFactor: CGFloat = 0.01

        static let titleLabelBottomPadding: CGFloat = 2
        static let titleLabelMinimumScaleFactor: CGFloat = 0.01

        static let topPadding: CGFloat = 15
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum InstructionView {
        static let subtitleLabelForeground: Color = .gray
    }
}
