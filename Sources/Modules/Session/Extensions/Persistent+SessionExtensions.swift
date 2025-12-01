//
//  Persistent+SessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Persistent {
    convenience init(_ userSessionServiceKey: UserDefaultsKey.UserSessionServiceDefaultsKey) {
        self.init(.userSessionService(userSessionServiceKey))
    }
}
