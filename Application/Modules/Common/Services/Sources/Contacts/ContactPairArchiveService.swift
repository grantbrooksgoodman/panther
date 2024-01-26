//
//  ContactPairArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public final class ContactPairArchiveService: Cacheable {
    // MARK: - Dependencies

    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    // Array
    private var archive: [ContactPair]? {
        didSet { persistedArchive = archive }
    }

    @Persistent(.contactPairArchive) private var persistedArchive: [ContactPair]?

    // Cache
    public let emptyCache: Cache
    public var cache: Cache

    // MARK: - Init

    public init() {
        cache = .init(
            [
                .contactPairsForContactHashes: [:],
                .contactPairsForUserHashes: [:],
            ]
        )
        emptyCache = cache
        archive = persistedArchive
    }

    // MARK: - Addition

    public func addValue(_ contactPair: ContactPair) {
        var values = archive ?? .init()

        guard !values.contains(contactPair) else { return }

        values.removeAll(where: { $0.contact.id == contactPair.contact.id })
        values.append(contactPair)
        archive = values

        Logger.log(
            .init(
                "Added contact pair to local archive.",
                extraParams: ["FullName": contactPair.contact.fullName,
                              "PhoneNumber": contactPair.numberPairs.first?.phoneNumber.formattedString() ?? ""],
                metadata: [self, #file, #function, #line]
            ),
            domain: .contacts
        )

        Observables.updatedContactPairArchive.trigger()
    }

    // MARK: - Removal

    public func clearArchive() {
        archive = nil
    }

    // MARK: - Retrieval

    public func getValue(contactHash: String) -> ContactPair? {
        if let cacheValue = cache.value(forKey: .contactPairsForContactHashes) as? [String: ContactPair],
           let match = cacheValue[contactHash] {
            return match
        }

        guard let contactPair = archive?
            .first(where: { $0.contact.compressedHash == contactHash }) else { return nil }

        var cacheValue = cache.value(forKey: .contactPairsForContactHashes) as? [String: ContactPair] ?? [:]
        cacheValue[contactHash] = contactPair
        cache.set(cacheValue, forKey: .contactPairsForContactHashes)
        return contactPair
    }

    public func getValue(userNumberHash: String) -> ContactPair? {
        if let cacheValue = cache.value(forKey: .contactPairsForUserHashes) as? [String: ContactPair],
           let match = cacheValue[userNumberHash] {
            return match
        }

        guard let contactPair = archive?
            .first(where: {
                (phoneNumberService.possibleHashes(for: $0.contact.phoneNumbers.compiledNumberStrings.unique) ?? []).contains(userNumberHash)
            }) else { return nil }

        var cacheValue = cache.value(forKey: .contactPairsForUserHashes) as? [String: ContactPair] ?? [:]
        cacheValue[userNumberHash] = contactPair
        cache.set(cacheValue, forKey: .contactPairsForUserHashes)
        return contactPair
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum ContactPairArchiveServiceCacheDomainKey: String, CaseIterable, Equatable {
        case contactPairsForContactHashes
        case contactPairsForUserHashes
    }
}

private extension Cache {
    convenience init(_ objects: [CacheDomain.ContactPairArchiveServiceCacheDomainKey: Any]) {
        var mappedObjects = [CacheDomain: Any]()
        objects.forEach { object in
            mappedObjects[.contactPairArchiveService(object.key)] = object.value
        }
        self.init(mappedObjects)
    }

    func set(_ value: Any, forKey key: CacheDomain.ContactPairArchiveServiceCacheDomainKey) {
        set(value, forKey: .contactPairArchiveService(key))
    }

    func value(forKey key: CacheDomain.ContactPairArchiveServiceCacheDomainKey) -> Any? {
        value(forKey: .contactPairArchiveService(key))
    }
}
