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

public extension UserDefaultsKey {
    /* Add values here for each new defaults key. */

    static func general(_ key: GeneralAppDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func audioService(_ key: AudioServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func contactPairArchiveService(_ key: ContactPairArchiveServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func contactSyncService(_ key: ContactSyncServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func conversationArchiveService(_ key: ConversationArchiveServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func coreNetworking(_ key: CoreNetworkingDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func devModeService(_ key: DevModeServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func reviewService(_ key: ReviewServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func settingsPageViewService(_ key: SettingsPageViewServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func updateService(_ key: UpdateServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
    static func userSessionService(_ key: UserSessionServiceDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
}
