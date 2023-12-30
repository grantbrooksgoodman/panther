//
//  Persistent+SessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Persistent {
    convenience init(_ userSessionServiceKey: UserDefaultsKeyDomain.UserSessionServiceDefaultsKey) {
        self.init(.app(.userSessionService(userSessionServiceKey)))
    }
}
