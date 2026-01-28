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

extension AppConstants.CGFloats {
    enum ConversationsPageView {
        static let composeToolbarButtonAnimationAmount: CGFloat = 1.4
        static let composeToolbarButtonAnimationDelay: CGFloat = 0.1
        static let composeToolbarButtonAnimationDuration: CGFloat = 0.4
        static let toolbarButtonFrameMinHeight: CGFloat = 30
        static let toolbarButtonFrameMinWidth: CGFloat = 30
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ConversationsPageView {
        static let composeToolbarButtonForeground: Color = .init(
            uiColor: Application.isInPrevaricationMode ? .black : !ThemeService.isAppDefaultThemeApplied ? .white : .systemBlue
        )

        // swiftlint:disable identifier_name
        static let createRandomMessagesToolbarButtonForeground: Color = .purple
        static let deleteConversationsToolbarButtonForeground: Color = .red
        // swiftlint:enable identifier_name

        static let settingsToolbarButtonForeground: Color = .init(
            uiColor: Application.isInPrevaricationMode ? .black : !ThemeService.isAppDefaultThemeApplied ? .white : .systemBlue
        )
        static let storageFullToolbarButtonForeground: Color = .red
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ConversationsPageView { // swiftlint:disable identifier_name line_length
        static let composeToolbarButtonImageSystemName = Application.isInPrevaricationMode ? "plus\(UIApplication.isFullyV26Compatible ? "" : ".circle.fill")" : "square.and.pencil"
        static let createRandomMessagesToolbarButtonImageSystemName = "sparkles.2"
        static let deleteConversationsToolbarButtonImageSystemName = "trash"
        static let settingsToolbarButtonImageSystemName = Application.isInPrevaricationMode ? "gearshape\(UIApplication.isFullyV26Compatible ? "" : ".circle.fill")" : "gearshape" // swiftlint:enable identifier_name line_length
        static let storageFullToolbarButtonImageSystemName = "exclamationmark.triangle"
    }
}
