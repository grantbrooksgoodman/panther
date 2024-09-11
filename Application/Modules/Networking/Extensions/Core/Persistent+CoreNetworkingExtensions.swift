//
//  Persistent+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Persistent {
    convenience init(_ coreNetworkingKey: UserDefaultsKey.CoreNetworkingDefaultsKey) {
        self.init(.coreNetworking(coreNetworkingKey))
    }
}
