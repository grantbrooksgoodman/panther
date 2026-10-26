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

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ChatGPTService {
        static let interMessageDelayMilliseconds: CGFloat = 750
        static let typingStatusParticipantCount = ChatPageViewService.TypingIndicator.participantCountThreshold
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatGPTService {
        static let languageCode = "en"

        static let phoneNumberCallingCode = "1"
        static let phoneNumberNationalNumber = "8005550199"
        static let phoneNumberRegionCode = "US"

        static let recipientQueries = {
            guard Dependency(\.build.isDeveloperModeEnabled).wrappedValue else {
                return [
                    "...",
                    "…",
                ]
            }

            return [
                "...",
                "…",
                "chat",
            ]
        }()
    }
}
