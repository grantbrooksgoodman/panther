//
//  UIApplication+CommonExtensions.swift
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

extension UIApplication {
    static var isGlassTintingEnabled: Bool {
        @Persistent(.isGlassTintingEnabled) var isGlassTintingEnabled: Bool?
        guard !Application.isInPrevaricationMode,
              UIApplication.v26FeaturesEnabled,
              isGlassTintingEnabled == true else { return false }
        return true
    }

    static var v26FeaturesEnabled: Bool {
        @Persistent(.v26FeaturesEnabled) var persistedValue: Bool?
        return UIApplication.isFullyV26Compatible && (persistedValue ?? true)
    }
}
