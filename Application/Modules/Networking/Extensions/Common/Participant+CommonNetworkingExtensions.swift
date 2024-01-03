//
//  Participant+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension Participant: Validatable {
    public var isWellFormed: Bool {
        !userIDKey.isBangQualifiedEmpty
    }
}
