//
//  AppConstants+ChatGPTService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// MARK: - String

extension AppConstants.Strings {
    enum ChatGPTService {
        static let languageCode = "en"

        static let phoneNumberCallingCode = "1"
        static let phoneNumberNationalNumber = "8005550199"
        static let phoneNumberRegionCode = "US"

        static let recipientQueries: Set<String> = [
            "...",
            "…",
        ]
    }
}
