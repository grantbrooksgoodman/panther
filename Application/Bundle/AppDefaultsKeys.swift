//
//  AppDefaultsKeys.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension UserDefaultsKeyDomain {
    enum AppDefaultsKey {
        /* Add cases here for each new defaults key. */

        case general(GeneralAppDefaultsKey)
        case contactPairArchiveService(ContactPairArchiveServiceDefaultsKey)
        case contactSyncService(ContactSyncServiceDefaultsKey)
        case conversationArchiveService(ConversationArchiveServiceDefaultsKey)
        case devModeService(DevModeServiceDefaultsKey)
        case notificationService(NotificationServiceDefaultsKey)
        case reviewService(ReviewServiceDefaultsKey)
        case updateService(UpdateServiceDefaultsKey)
        case userArchiveService(UserArchiveServiceDefaultsKey)
        case userSessionService(UserSessionServiceDefaultsKey)

        public var rawValue: String {
            switch self {
            case let .general(key):
                return key.rawValue

            case let .contactPairArchiveService(key):
                return key.rawValue

            case let .contactSyncService(key):
                return key.rawValue

            case let .conversationArchiveService(key):
                return key.rawValue

            case let .devModeService(key):
                return key.rawValue

            case let .notificationService(key):
                return key.rawValue

            case let .reviewService(key):
                return key.rawValue

            case let .updateService(key):
                return key.rawValue

            case let .userArchiveService(key):
                return key.rawValue

            case let .userSessionService(key):
                return key.rawValue
            }
        }
    }
}
