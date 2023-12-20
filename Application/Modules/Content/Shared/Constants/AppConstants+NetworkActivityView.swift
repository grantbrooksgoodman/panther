//
//  AppConstants+NetworkActivityView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum NetworkActivityView {
        public static let frameHeight: CGFloat = 40
        public static let frameWidth: CGFloat = 40
        public static let hiddenYOffset: CGFloat = -1000
        public static let hideIndicatorTaskDelaySeconds: CGFloat = 1.25
        public static let padding: CGFloat = 5
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum NetworkActivityView {
        public static let progressViewTint: Color = .white
    }
}
