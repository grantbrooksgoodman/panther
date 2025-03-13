//
//  UserDefaultsKeyDomain+SessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension UserDefaultsKey {
    enum UserSessionServiceDefaultsKey: String {
        case currentUserID
        case offlineCurrentUser
    }
}
