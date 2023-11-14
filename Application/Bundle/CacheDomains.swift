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

    case `default`(DefaultCacheDomainKey)

    // MARK: - Properties

    public var rawValue: String {
        switch self {
        case let .default(key):
            return key.rawValue
        }
    }
}

public enum DefaultCacheDomainKey: String {
    case cacheableValueKey
}
