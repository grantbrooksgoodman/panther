//
//  PersistentStorageKey+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension PersistentStorageKey {
    /// The persistent storage keys scoped to ``Application``.
    enum ApplicationStorageKey: String {
        case buildMilestoneString
        case hasRunOnce
        case isInStagingMode
    }

    /// The persistent storage keys scoped to ``AIEnhancedTranslationService``.
    enum AIEnhancedTranslationServiceStorageKey: String { // swiftlint:disable:next identifier_name
        case presentedAIEnhancedTranslationPermissionPageAtStartup
    }

    /// The persistent storage keys scoped to ``AudioService``.
    enum AudioServiceStorageKey: String {
        case acknowledgedAudioMessagesUnsupported
    }

    /// The persistent storage keys scoped to ``BreadcrumbsCaptureService``.
    enum BreadcrumbsCaptureServiceStorageKey: String {
        case breadcrumbsCaptureFrequency
        case breadcrumbsCaptureHistory
    }

    /// The persistent storage keys scoped to ``ContactPairArchiveService``.
    enum ContactPairArchiveServiceStorageKey: String {
        case contactPairArchive
        case lastContactSyncDate
        case unknownContactPairArchive
    }

    /// The persistent storage keys scoped to ``MessageRetranslationService``.
    enum MessageRetranslationServiceStorageKey: String {
        case retranslatedMessageIDs
        case retranslationOutputHashes
    }

    /// The persistent storage keys scoped to ``PenPalsService``.
    enum PenPalsServiceStorageKey: String {
        case presentedPenPalsPermissionPageAtStartup
    }

    /// The persistent storage keys scoped to ``ReviewService``.
    enum ReviewServiceStorageKey: String {
        case appOpenCount
        case lastRequestedReviewForBuildNumber
    }

    /// The persistent storage keys scoped to ``UpdateService``.
    enum UpdateServiceStorageKey: String {
        case buildNumberWhenLastForcedToUpdate
        case firstPostponedUpdate
        case relaunchesSinceLastPostponedUpdate
    }
}
