//
//  Participant+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Networking

extension Participant: Validatable {
    var isWellFormed: Bool {
        !userID.isBangQualifiedEmpty
    }
}
