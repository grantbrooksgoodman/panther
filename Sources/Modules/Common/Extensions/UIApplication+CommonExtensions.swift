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

public extension UIApplication {
    static var isGlassTintingEnabled: Bool {
        @Persistent(.isGlassTintingEnabled) var isGlassTintingEnabled: Bool?
        return !Application.isInPrevaricationMode && isGlassTintingEnabled == true
    }

    static var v26FeaturesEnabled: Bool {
        @Persistent(.v26FeaturesEnabled) var persistedValue: Bool?
        if persistedValue == nil { persistedValue = true }
        return UIApplication.isFullyV26Compatible && persistedValue == true
    }
}
