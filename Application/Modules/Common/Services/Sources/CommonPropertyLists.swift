//
//  CommonPropertyLists.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct CommonPropertyLists {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case callingCodes
        case lookupTables
    }

    // MARK: - Properties

    public static let shared = CommonPropertyLists()

    private let cache: Cache<CacheKey> = .init()

    // MARK: - Computed Properties

    public var callingCodes: [String: String] {
        @Dependency(\.mainBundle) var mainBundle: Bundle
        if let cachedValue = cache.value(forKey: .callingCodes) as? [String: String],
           !cachedValue.isEmpty {
            return cachedValue
        }

        guard let filePath = mainBundle.url(forResource: "CallingCodes", withExtension: "plist"),
              let data = try? Data(contentsOf: filePath),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            return .init()
        }

        cache.set(dictionary, forKey: .callingCodes)
        return dictionary
    }

    public var lookupTables: [String: [String]] {
        @Dependency(\.mainBundle) var mainBundle: Bundle
        if let cachedValue = cache.value(forKey: .lookupTables) as? [String: [String]],
           !cachedValue.isEmpty {
            return cachedValue
        }

        guard let filePath = mainBundle.url(forResource: "LookupTables", withExtension: "plist"),
              let data = try? Data(contentsOf: filePath),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String]] else {
            return .init()
        }

        cache.set(dictionary, forKey: .lookupTables)
        return dictionary
    }

    // MARK: - Init

    private init() {}

    // MARK: - Clear Cache

    public func clearCache() {
        cache.clear()
    }
}
