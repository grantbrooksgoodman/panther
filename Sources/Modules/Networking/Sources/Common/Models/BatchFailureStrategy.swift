//
//  BatchFailureStrategy.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A strategy for how a batched operation responds to a failure.
enum BatchFailureStrategy {
    /// Continues processing the remaining items after a failure.
    case continueOnFailure

    /// Stops processing and returns after the first failure.
    case returnOnFailure
}
