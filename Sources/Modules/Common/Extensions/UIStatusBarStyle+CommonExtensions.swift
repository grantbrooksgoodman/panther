//
//  UIStatusBarStyle+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

@MainActor
extension UIStatusBarStyle {
    /// A status bar style derived from the app's current theme and presentation state.
    ///
    /// This property resolves to `lightContent` when a theme other than the app default is
    /// applied, when dark mode is active, or – when the app does not run with full iOS 26
    /// compatibility – when ``Application/isInPrevaricationMode`` is `true` or a sheet is being
    /// presented. Otherwise, it resolves to `darkContent`.
    static var appAware: UIStatusBarStyle {
        @Dependency(\.uiApplication.isPresentingSheet) var isPresentingSheet: Bool

        let isAppDefaultThemeApplied = ThemeService.isAppDefaultThemeApplied
        let isInPrevaricationMode = Application.isInPrevaricationMode
        let isDarkModeActive = ThemeService.isDarkModeActive

        return !isAppDefaultThemeApplied ||
            isDarkModeActive ||
            (isInPrevaricationMode && !UIApplication.isFullyV26Compatible) ||
            (isPresentingSheet && !UIApplication.isFullyV26Compatible) ? .lightContent : .darkContent
    }

    /// A status bar style that resolves to `lightContent` unless the app's state calls for dark
    /// content.
    ///
    /// When the app does not run with full iOS 26 compatibility, this property always resolves
    /// to `lightContent`. Otherwise, it resolves to `darkContent` when
    /// ``Application/isInPrevaricationMode`` is `true` or dark mode is inactive, and to
    /// `lightContent` when dark mode is active.
    static var conditionalLightContent: UIStatusBarStyle {
        guard UIApplication.isFullyV26Compatible else { return .lightContent }
        return Application.isInPrevaricationMode || !ThemeService.isDarkModeActive ? .darkContent : .lightContent
    }
}
