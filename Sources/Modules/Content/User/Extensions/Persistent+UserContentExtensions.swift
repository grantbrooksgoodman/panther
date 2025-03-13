//
//  Persistent+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Persistent {
    convenience init(_ settingsPageViewServiceKey: UserDefaultsKey.SettingsPageViewServiceDefaultsKey) {
        self.init(.settingsPageViewService(settingsPageViewServiceKey))
    }
}
