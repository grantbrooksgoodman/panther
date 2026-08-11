//
//  AppConstants+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum CommonNetworkingExtensions {
        enum Duration {
            static let transferTimeoutBytesPerMegabyte: Double = 1_048_576
            static let transferTimeoutFloorSeconds: Double = 30
            static let transferTimeoutMaxSeconds: Double = 300
            static let transferTimeoutSecondsPerMegabyte: Double = 10
        }
    }
}
