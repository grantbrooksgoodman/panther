//
//  Cacheable.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol Cacheable {
    // MARK: - Properties

    var cache: Cache { get }
    var emptyCache: Cache { get }

    // MARK: - Methods

    func clearCache()
}

public final class Cache {
    // MARK: - Properties

    private let threadLock = NSLock()

    private var objects: [CacheDomain: Any]

    // MARK: - Init

    public init(_ objects: [CacheDomain: Any]) {
        self.objects = objects
    }

    // MARK: - Methods

    // FIXME: Experienced BAD_ACCESS crash here. Tried mainQueue.(a)sync; serialQueue; Task { @MainActor in }. Using NSLock for now.
    public func set(_ value: Any, forKey key: CacheDomain) {
        threadLock.lock()
        objects[key] = value
        threadLock.unlock()
    }

    public func removeObject(forKey key: CacheDomain) {
        threadLock.lock()
        objects[key] = nil
        threadLock.unlock()
    }

    // FIXME: Seeing access races occur here.
    public func value(forKey key: CacheDomain) -> Any? {
        return objects[key]
    }
}
