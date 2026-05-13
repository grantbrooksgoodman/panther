//
//  AIEnhancedTranslationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

struct AIEnhancedTranslationService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Set Did Grant AI-Enhanced Translation Permission

    func setDidGrantAIEnhancedTranslationPermission(
        _ didGrantAIEnhancedTranslationPermission: Bool
    ) async -> Exception? {
        guard let currentUser = userSession.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self),
            )
        }

        do {
            Observables.didGrantAIEnhancedTranslationPermission.value = didGrantAIEnhancedTranslationPermission

            Networking.config.setIsEnhancedDialogTranslationEnabled(
                didGrantAIEnhancedTranslationPermission
            )

            return try await userSession.setCurrentUser(
                currentUser.update(
                    \.aiEnhancedTranslationsEnabled,
                    to: didGrantAIEnhancedTranslationPermission
                ),
                repopulateValuesIfNeeded: true
            )
        } catch {
            return error
        }
    }
}
