//
//  CommonPropertyLists.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public final class CommonPropertyLists {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case callingCodes
        case lookupTables
    }

    // MARK: - Dependencies

    @Dependency(\.mainBundle) private var mainBundle: Bundle

    // MARK: - Properties

    public static let shared = CommonPropertyLists()

    @Cached(CacheKey.callingCodes) private var cachedCallingCodes: [String: String]?
    @Cached(CacheKey.lookupTables) private var cachedLookupTables: [String: [String]]?

    // MARK: - Computed Properties

    public var callingCodes: [String: String] {
        if let cachedCallingCodes,
           !cachedCallingCodes.isEmpty {
            return cachedCallingCodes
        }

        guard let filePath = mainBundle.url(forResource: "CallingCodes", withExtension: "plist"),
              let data = try? Data(contentsOf: filePath),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            return .init()
        }

        cachedCallingCodes = dictionary
        return dictionary
    }

    public var lookupTables: [String: [String]] {
        if let cachedLookupTables,
           !cachedLookupTables.isEmpty {
            return cachedLookupTables
        }

        guard let filePath = mainBundle.url(forResource: "LookupTables", withExtension: "plist"),
              let data = try? Data(contentsOf: filePath),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String]] else {
            return .init()
        }

        cachedLookupTables = dictionary
        return dictionary
    }

    // MARK: - Init

    private init() {}

    // MARK: - Clear Cache

    public func clearCache() {
        cachedCallingCodes = nil
        cachedLookupTables = nil
    }
}
