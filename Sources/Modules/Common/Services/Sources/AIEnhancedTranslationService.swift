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

    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService

    // MARK: - Set Did Grant AI-Enhanced Translation Permission

    func setDidGrantAIEnhancedTranslationPermission(
        _ didGrantAIEnhancedTranslationPermission: Bool
    ) async throws(Exception) {
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        Observables.didGrantAIEnhancedTranslationPermission.value = didGrantAIEnhancedTranslationPermission

        Networking.config.setIsEnhancedDialogTranslationEnabled(
            didGrantAIEnhancedTranslationPermission
        )

        // NIT: Can we be upserting here?
        _ = try await currentUser.update(
            \.aiEnhancedTranslationsEnabled,
            to: didGrantAIEnhancedTranslationPermission
        )
    }
}
