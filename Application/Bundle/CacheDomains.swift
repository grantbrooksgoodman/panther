//
//  CacheDomains.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/**
 Use this enum to define domains for new objects conforming to `Cacheable`.
 */
public enum CacheDomain: Equatable, Hashable {
    // MARK: - Cases

    case commonPropertyLists(CommonPropertyListsCacheDomainKey)
    case contactService(ContactServiceCacheDomainKey)
    case regionDetailService(RegionDetailServiceCacheDomainKey)
    case settingsPageViewService(SettingsPageViewServiceCacheDomainKey)
    case userService(UserServiceCacheDomainKey)

    // MARK: - Properties

    public var rawValue: String {
        switch self {
        case let .commonPropertyLists(key):
            return key.rawValue

        case let .contactService(key):
            return key.rawValue

        case let .regionDetailService(key):
            return key.rawValue

        case let .settingsPageViewService(key):
            return key.rawValue

        case let .userService(key):
            return key.rawValue
        }
    }
}
