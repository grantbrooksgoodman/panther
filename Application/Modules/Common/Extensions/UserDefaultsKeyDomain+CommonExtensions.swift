//
//  UserDefaultsKeyDomain+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension UserDefaultsKeyDomain {
    enum GeneralAppDefaultsKey: String {
        case `default`
    }

    enum ContactPairArchiveServiceDefaultsKey: String {
        case contactPairArchive
    }

    enum ContactSyncServiceDefaultsKey: String {
        case localUserHashes
        case mismatchedHashes
        case serverUserHashes
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
