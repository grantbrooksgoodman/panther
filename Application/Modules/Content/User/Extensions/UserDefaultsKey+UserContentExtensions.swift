//
//  UserDefaultsKey+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension UserDefaultsKey {
    // TODO: Expand this idea into a full-fledged service. Important for IAP down the line.
    enum FeatureFlagDefaultsKey: String {
        case isReactionsEnabled
    }

    enum SettingsPageViewServiceDefaultsKey: String {
        case didClearCaches
    }
}
