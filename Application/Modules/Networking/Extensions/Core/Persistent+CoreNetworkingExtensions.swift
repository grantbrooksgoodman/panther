//
//  Persistent+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Persistent {
    convenience init(_ coreNetworkingKey: UserDefaultsKeyDomain.CoreNetworkingDefaultsKey) {
        self.init(.app(.coreNetworking(coreNetworkingKey)))
    }
}
