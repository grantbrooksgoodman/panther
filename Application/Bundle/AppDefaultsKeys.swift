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
        case reviewService(ReviewServiceDefaultsKey)
        case updateService(UpdateServiceDefaultsKey)

        public var rawValue: String {
            switch self {
            case let .general(key):
                return key.rawValue

            case let .contactPairArchiveService(key):
                return key.rawValue

            case let .reviewService(key):
                return key.rawValue

            case let .updateService(key):
                return key.rawValue
            }
        }
    }
}
