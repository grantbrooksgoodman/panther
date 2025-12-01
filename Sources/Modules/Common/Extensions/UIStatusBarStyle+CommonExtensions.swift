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
            (isPresentingSheet && !UIApplication.v26FeaturesEnabled) ? .lightContent : .darkContent
    }

    static var conditionalLightContent: UIStatusBarStyle {
        (!ThemeService.isDarkModeActive && UIApplication.v26FeaturesEnabled) ||
            (Application.isInPrevaricationMode && UIApplication.isFullyV26Compatible)
            ? .darkContent : .lightContent
    }
}
