//
//  StoredItemKeys.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension StoredItemKey {
    static let `default`: StoredItemKey = .init("default")
}

extension RuntimeStorage {
    /* Add new static properties here for quick access. */

    static var `default`: String? { retrieve(.default) as? String }
}
