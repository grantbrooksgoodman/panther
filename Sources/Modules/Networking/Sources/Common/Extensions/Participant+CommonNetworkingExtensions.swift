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
    /// A Boolean value that indicates whether the participant is well-formed, having a non-empty
    /// user identifier.
    var isWellFormed: Bool {
        !userID.isBangQualifiedEmpty
    }
}
