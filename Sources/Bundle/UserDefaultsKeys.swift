//
//  UserDefaultsKeys.swift
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

public extension UserDefaultsKey {
    // MARK: - Types

    struct PermanentKeyDelegate: AppSubsystem.Delegates.PermanentUserDefaultsKeyDelegate {
        public let permanentKeys: [UserDefaultsKey] = [
            .application(.buildMilestoneString),
            .application(.hasRunOnce),
            .application(.isGlassTintingEnabled),
            .application(.v26FeaturesEnabled),
            .networking(.isNetworkActivityIndicatorEnabled),
            .networking(.networkEnvironment),
        ]
    }

    // MARK: - Methods

    /* Add values here for each new defaults key. */

    static func application(_ key: ApplicationDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func audioService(_ key: AudioServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func breadcrumbsCaptureService(_ key: BreadcrumbsCaptureServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func contactPairArchiveService(_ key: ContactPairArchiveServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func conversationArchiveService(_ key: ConversationArchiveServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func penPalsService(_ key: PenPalsServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func reviewService(_ key: ReviewServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func updateService(_ key: UpdateServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func userSessionService(_ key: UserSessionServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
}
