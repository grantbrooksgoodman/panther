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

struct AIEnhancedTranslationService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Set Did Grant AI-Enhanced Translation Permission

    func setDidGrantAIEnhancedTranslationPermission(_ didGrantAIEnhancedTranslationPermission: Bool) async -> Exception? {
        guard let currentUser = userSession.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self),
            )
        }

        let updateValueResult = await currentUser.updateValue(
            didGrantAIEnhancedTranslationPermission,
            forKey: .aiEnhancedTranslationsEnabled
        )

        switch updateValueResult {
        case let .success(user):
            Observables.didGrantAIEnhancedTranslationPermission.value = didGrantAIEnhancedTranslationPermission
            return userSession.setCurrentUser(user)

        case let .failure(exception):
            return exception
        }
    }
}
