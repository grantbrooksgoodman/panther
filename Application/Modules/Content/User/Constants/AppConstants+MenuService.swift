//
//  AppConstants+MenuService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 07/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum MenuService {
        public static let longPressGestureMinimumPressDuration: CGFloat = 0.3
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum MenuService {
        public static let copyActionIdentifierRawValue = "copy"
        public static let speakActionIdentifierRawValue = "speak"
    }
}
