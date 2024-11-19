//
//  AppConstants+ConversationsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ConversationsPageView {
        public static let composeToolbarButtonAnimationAmount: CGFloat = 1.4
        public static let composeToolbarButtonAnimationDelay: CGFloat = 0.1
        public static let composeToolbarButtonAnimationDuration: CGFloat = 0.4
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ConversationsPageView {
        public static let composeToolbarButtonLabelImageSystemName = Application.isInPrevaricationMode ? "plus.circle.fill" : "square.and.pencil"
        // swiftlint:disable:next identifier_name
        public static let settingsToolbarButtonLabelImageSystemName = Application.isInPrevaricationMode ? "gearshape.circle.fill" : "gearshape"
    }
}
