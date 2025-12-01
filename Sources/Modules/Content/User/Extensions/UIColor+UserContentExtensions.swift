//
//  UIColor+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

extension UIColor {
    static var accentOrSystemBlue: UIColor {
        if Application.isInPrevaricationMode ||
            (UIApplication.v26FeaturesEnabled && ThemeService.isAppDefaultThemeApplied) {
            return .systemBlue
        }

        return .accent
    }
}
