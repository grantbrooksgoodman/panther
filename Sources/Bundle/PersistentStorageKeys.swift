//
//  PersistentStorageKeys.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/// Use this extension to declare which persistent storage keys
/// should survive a reset.
///
/// Register keys as permanent when they store critical app state –
/// such as authentication tokens or installation identifiers – that
/// must be preserved when the user or the subsystem resets
/// persistent storage.
extension PersistentStorageKey {
    // MARK: - Types

    /// The delegate that declares which persistent storage keys are
    /// preserved during a reset.
    struct PermanentKeyDelegate: AppSubsystem.Delegates.PermanentPersistentStorageKeyDelegate {
        /// The keys that should survive a persistent storage reset.
        let permanentKeys: [PersistentStorageKey] = [
            .application(.buildMilestoneString),
            .application(.hasRunOnce),
            .breadcrumbsCaptureService(.breadcrumbsCaptureHistory),
            .networking(.isNetworkActivityIndicatorEnabled),
            .networking(.networkEnvironment),
        ]
    }

    // MARK: - Methods

    static func application(
        _ key: ApplicationStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func aiEnhancedTranslationService(
        _ key: AIEnhancedTranslationServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func audioService(
        _ key: AudioServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func breadcrumbsCaptureService(
        _ key: BreadcrumbsCaptureServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func contactPairArchiveService(
        _ key: ContactPairArchiveServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func conversationArchiveService(
        _ key: ConversationArchiveServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func messageRetranslationService(
        _ key: MessageRetranslationServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func penPalsService(
        _ key: PenPalsServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func reviewService(
        _ key: ReviewServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func updateService(
        _ key: UpdateServiceStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }

    static func userSessionService(
        _ key: UserSessionServiceStorageKey
    ) -> PersistentStorageKey {
        .init(
            key.rawValue
        )
    }
}
