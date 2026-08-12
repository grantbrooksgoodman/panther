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

/// Use ``CommonPropertyLists`` to read phone number reference data bundled with the app as
/// property lists.
///
/// Loaded values are cached in memory.
final class CommonPropertyLists: @unchecked Sendable {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case callingCodes
        case lookupTables
    }

    // MARK: - Dependencies

    @Dependency(\.mainBundle) private var mainBundle: Bundle

    // MARK: - Properties

    /// The shared property lists instance.
    static let shared = CommonPropertyLists()

    @Cached(CacheKey.callingCodes) private var cachedCallingCodes: [String: String]?
    @Cached(CacheKey.lookupTables) private var cachedLookupTables: [String: [String]]?

    // MARK: - Computed Properties

    /// A dictionary that maps region codes to their international calling codes.
    ///
    /// The dictionary is loaded from the bundled `CallingCodes.plist` resource and cached in
    /// memory. If the resource cannot be loaded, this property is an empty dictionary.
    var callingCodes: [String: String] {
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

    /// A dictionary that maps national phone number lengths, as strings, to the calling codes
    /// whose numbers have that length.
    ///
    /// The dictionary is loaded from the bundled `LookupTables.plist` resource and cached in
    /// memory. If the resource cannot be loaded, this property is an empty dictionary.
    var lookupTables: [String: [String]] {
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

    /// Removes every cached property list value.
    func clearCache() {
        cachedCallingCodes = nil
        cachedLookupTables = nil
    }
}
