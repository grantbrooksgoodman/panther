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
import Redux

public final class CommonPropertyLists: Cacheable {
    // MARK: - Properties

    public let emptyCache: Cache
    public var cache: Cache

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

    public init() {
        emptyCache = .init(
            [
                .callingCodes: [String: String](),
                .lookupTables: [String: [String]](),
            ]
        )
        cache = emptyCache
    }

    // MARK: - Clear Cache

    public func clearCache() {
        CacheDomain.CommonPropertyListsCacheDomainKey.allCases.forEach { cache.removeObject(forKey: .commonPropertyLists($0)) }
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum CommonPropertyListsCacheDomainKey: String, CaseIterable, Equatable {
        case callingCodes
        case lookupTables
    }
}

private extension Cache {
    convenience init(_ objects: [CacheDomain.CommonPropertyListsCacheDomainKey: Any]) {
        var mappedObjects = [CacheDomain: Any]()
        objects.forEach { object in
            mappedObjects[.commonPropertyLists(object.key)] = object.value
        }
        self.init(mappedObjects)
    }

    func set(_ value: Any, forKey key: CacheDomain.CommonPropertyListsCacheDomainKey) {
        set(value, forKey: .commonPropertyLists(key))
    }

    func value(forKey key: CacheDomain.CommonPropertyListsCacheDomainKey) -> Any? {
        value(forKey: .commonPropertyLists(key))
    }
}
