//
//  UserDefaultsKeyDomain+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension UserDefaultsKey {
    // MARK: - Types

    enum GeneralAppDefaultsKey: String {
        case `default`
    }

    enum AudioServiceDefaultsKey: String {
        case acknowledgedAudioMessagesUnsupported
    }

    enum ContactPairArchiveServiceDefaultsKey: String {
        case contactPairArchive
    }

    enum ContactSyncServiceDefaultsKey: String {
        case localUserNumberHashes
        case mismatchedHashes
        case serverUserNumberHashes
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

    // MARK: - Properties

    static var permanentKeys: [UserDefaultsKey] {
        var keys: [UserDefaultsKey] = [
            .application(.buildMilestoneString),
            .init("isNetworkActivityIndicatorEnabled"),
            .init("networkEnvironment"),
        ]
        keys.append(contentsOf: UserDefaultsKey.coreKeys)
        return keys
    }
}
