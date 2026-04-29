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
    enum ApplicationStorageKey: String {
        case buildMilestoneString
        case hasRunOnce
    }

    enum AIEnhancedTranslationServiceStorageKey: String { // swiftlint:disable:next identifier_name
        case presentedAIEnhancedTranslationPermissionPageAtStartup
    }

    enum AudioServiceStorageKey: String {
        case acknowledgedAudioMessagesUnsupported
    }

    enum BreadcrumbsCaptureServiceStorageKey: String {
        case breadcrumbsCaptureFrequency
        case breadcrumbsCaptureHistory
    }

    enum ContactPairArchiveServiceStorageKey: String {
        case contactPairArchive
        case unknownContactPairArchive
    }

    enum MessageRetranslationServiceStorageKey: String {
        case retranslatedMessageIDs
    }

    enum PenPalsServiceStorageKey: String {
        case presentedPenPalsPermissionPageAtStartup
    }

    enum ReviewServiceStorageKey: String {
        case appOpenCount
        case lastRequestedReviewForBuildNumber
    }

    enum UpdateServiceStorageKey: String {
        case buildNumberWhenLastForcedToUpdate
        case firstPostponedUpdate
        case relaunchesSinceLastPostponedUpdate
    }
}
