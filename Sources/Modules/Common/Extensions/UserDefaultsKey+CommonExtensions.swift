//
//  UserDefaultsKey+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension UserDefaultsKey {
    enum ApplicationDefaultsKey: String {
        case buildMilestoneString
        case hasRunOnce
    }

    enum AudioServiceDefaultsKey: String {
        case acknowledgedAudioMessagesUnsupported
    }

    enum BreadcrumbsCaptureServiceDefaultsKey: String {
        case breadcrumbsCaptureHistory
        case breadcrumbsCaptureFrequency
    }

    enum ContactPairArchiveServiceDefaultsKey: String {
        case contactPairArchive
        case unknownContactPairArchive
    }

    enum MessageRetranslationServiceDefaultsKey: String {
        case retranslatedMessageIDs
    }

    enum PenPalsServiceDefaultsKey: String {
        case presentedPenPalsPermissionPageAtStartup
    }

    enum ReviewServiceDefaultsKey: String {
        case appOpenCount
        case lastRequestedReviewForBuildNumber
    }

    enum UpdateServiceDefaultsKey: String {
        case buildNumberWhenLastForcedToUpdate
        case firstPostponedUpdate
        case relaunchesSinceLastPostponedUpdate
    }
}
