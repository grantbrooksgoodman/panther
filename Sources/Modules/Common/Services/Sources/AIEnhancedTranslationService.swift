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

/// Use ``AIEnhancedTranslationService`` to record the user's choice about AI-enhanced
/// translation.
struct AIEnhancedTranslationService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService

    // MARK: - Properties

    @SharedState(\.didGrantAIEnhancedTranslationPermission) private var didGrantAIEnhancedTranslationPermission

    // MARK: - Set Did Grant AI-Enhanced Translation Permission

    /// Records whether the user granted permission for AI-enhanced translation.
    ///
    /// This method updates the shared permission state, enables or disables enhanced dialog
    /// translation for networking, and persists the choice to the current user's remote record.
    ///
    /// - Parameter didGrantAIEnhancedTranslationPermission: A Boolean value that indicates
    ///   whether the user granted permission.
    ///
    /// - Throws: An `Exception` if the current user has not been set, or if the update fails.
    func setDidGrantAIEnhancedTranslationPermission(
        _ didGrantAIEnhancedTranslationPermission: Bool
    ) async throws(Exception) {
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        self.didGrantAIEnhancedTranslationPermission = didGrantAIEnhancedTranslationPermission
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
