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

extension UIStatusBarStyle {
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

    static var conditionalLightContent: UIStatusBarStyle {
        guard UIApplication.isFullyV26Compatible else { return .lightContent }
        return Application.isInPrevaricationMode || !ThemeService.isDarkModeActive ? .darkContent : .lightContent
    }
}
