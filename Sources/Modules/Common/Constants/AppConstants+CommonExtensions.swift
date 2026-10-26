//
//  AppConstants+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum CommonExtensions {
        enum LanguageModelSession {
            static let submissionRetryCountMaximum: CGFloat = 2
            static let submissionRetryDelayMilliseconds: CGFloat = 1000
        }
    }
}
