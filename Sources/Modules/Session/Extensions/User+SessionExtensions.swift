//
//  User+SessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension User {
    var isObfuscatedPenPalWithCurrentUser: Bool {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        return currentUser?.obfuscatedPenPalUsers?.map(\.id).contains(id) ?? false
    }
}
