//
//  Persistent+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Persistent {
    convenience init(_ generalKey: UserDefaultsKeyDomain.GeneralAppDefaultsKey) {
        self.init(.app(.general(generalKey)))
    }

    convenience init(_ updateServiceKey: UserDefaultsKeyDomain.UpdateServiceDefaultsKey) {
        self.init(.app(.updateService(updateServiceKey)))
    }
}
