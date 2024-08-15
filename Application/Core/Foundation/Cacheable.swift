//
//  Cacheable.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol Cacheable {
    // MARK: - Associated Types

    associatedtype CacheKey: RawRepresentable where CacheKey.RawValue: StringProtocol, CacheKey: CaseIterable

    // MARK: - Methods

    func clear()
    func removeObject(forKey key: CacheKey)
    func set(_ value: Any, forKey key: CacheKey)
    func value(forKey key: CacheKey) -> Any?
}

public struct Cache<KeyType: RawRepresentable> where KeyType.RawValue: StringProtocol, KeyType: CaseIterable {
    // MARK: - Properties

    fileprivate let cache: NSCache<NSString, AnyObject> = .init()

    // MARK: - Init

    public init() {}
}

extension Cache: Cacheable {
    // MARK: - Type Aliases

    public typealias CacheKey = KeyType

    // MARK: - Cacheable Conformance

    public func clear() {
        CacheKey.allCases.forEach { removeObject(forKey: $0) }
    }

    public func removeObject(forKey key: KeyType) {
        guard let keyString = key.rawValue as? NSString else { return }
        cache.removeObject(forKey: keyString)
    }

    public func set(_ value: Any, forKey key: KeyType) {
        guard let keyString = key.rawValue as? NSString else { return }
        cache.setObject(value as AnyObject, forKey: keyString)
    }

    public func value(forKey key: KeyType) -> Any? {
        guard let keyString = key.rawValue as? NSString else { return nil }
        return cache.object(forKey: keyString)
    }
}
