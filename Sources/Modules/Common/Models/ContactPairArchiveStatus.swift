//
//  ContactPairArchiveStatus.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum ContactPairArchiveStatus {
    // MARK: - Properties

    public private(set) static var needsUpdate = false

    // MARK: - Set Needs Update

    public static func setNeedsUpdate(_ needsUpdate: Bool) {
        self.needsUpdate = needsUpdate
    }
}
