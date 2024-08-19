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
import CoreArchitecture

public final class ContactPairArchiveService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case archive
        case contactPairsForContactHashes
        case contactPairsForPhoneNumbers
        case contactPairsForUserNumberHashes
    }

    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    // Array
    @Cached(CacheKey.archive) private var cachedArchive: [ContactPair]?
    @Persistent(.contactPairArchive) private var persistedArchive: [ContactPair]?

    // Dictionary
    @Cached(CacheKey.contactPairsForContactHashes) private var cachedContactPairsForContactHashes: [String: ContactPair]?
    @Cached(CacheKey.contactPairsForPhoneNumbers) private var cachedContactPairsForPhoneNumbers: [String: ContactPair]?
    @Cached(CacheKey.contactPairsForUserNumberHashes) private var cachedContactPairsForUserNumberHashes: [String: ContactPair]?

    // MARK: - Computed Properties

    private var archive: [ContactPair] {
        get { cachedArchive ?? persistedArchive ?? [] }

        set {
            cachedArchive = newValue
            persistedArchive = newValue
            persistValuesForNotificationExtension()
        }
    }

    // MARK: - Init

    public init() {
        persistValuesForNotificationExtension()
    }

    // MARK: - Addition

    public func addValues(_ contactPairs: [ContactPair]) {
        var values = archive

        for contactPair in contactPairs where !values.contains(contactPair) {
            values.removeAll(where: { $0.contact.id == contactPair.contact.id })
            values.append(contactPair)

            Logger.log(
                .init(
                    "Added contact pair to persisted archive.",
                    extraParams: ["FullName": contactPair.contact.fullName,
                                  "PhoneNumber": contactPair.numberPairs.first?.phoneNumber.formattedString() ?? ""],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .contacts
            )
        }

        archive = values
        cachedContactPairsForContactHashes = cachedContactPairsForContactHashes?.filter { !contactPairs.contains($0.value) }
        cachedContactPairsForPhoneNumbers = cachedContactPairsForPhoneNumbers?.filter { !contactPairs.contains($0.value) }
        cachedContactPairsForUserNumberHashes = cachedContactPairsForUserNumberHashes?.filter { !contactPairs.contains($0.value) }

        coreUtilities.clearCaches(domains: [.contactImageArchive])
        Observables.updatedContactPairArchive.trigger()
    }

    // MARK: - Removal

    public func clearArchive() {
        archive = []
        cachedContactPairsForContactHashes = nil
        cachedContactPairsForPhoneNumbers = nil
        cachedContactPairsForUserNumberHashes = nil
        coreUtilities.clearCaches(domains: [.contactImageArchive])
    }

    public func removeValue(userNumberHashes: [String]) {
        func satisfiesConstraints(_ contactPair: ContactPair) -> Bool {
            let possibleHashes = phoneNumberService.possibleHashes(for: contactPair.contact.phoneNumbers.compiledNumberStrings.unique) ?? []
            return possibleHashes.containsAnyString(in: userNumberHashes)
        }

        guard archive.contains(where: { satisfiesConstraints($0) }) else { return }
        archive.removeAll(where: { satisfiesConstraints($0) })
        cachedContactPairsForContactHashes = cachedContactPairsForContactHashes?.filter { !satisfiesConstraints($0.value) }
        cachedContactPairsForPhoneNumbers = cachedContactPairsForPhoneNumbers?.filter { !satisfiesConstraints($0.value) }
        cachedContactPairsForUserNumberHashes = cachedContactPairsForUserNumberHashes?.filter { !satisfiesConstraints($0.value) }

        coreUtilities.clearCaches(domains: [.contactImageArchive])
        Observables.updatedContactPairArchive.trigger()

        Logger.log(
            .init(
                "Removed contact pair from persisted archive.",
                extraParams: ["UserNumberHashes": userNumberHashes],
                metadata: [self, #file, #function, #line]
            ),
            domain: .contacts
        )
    }

    // MARK: - Retrieval

    public func getValue(contactHash: String) -> ContactPair? {
        if let cachedContactPairsForContactHashes,
           let cachedValue = cachedContactPairsForContactHashes[contactHash] {
            return cachedValue
        }

        guard let valueForContactHash = archive.first(where: { $0.contact.encodedHash == contactHash }) else { return nil }

        var newCacheValue = cachedContactPairsForContactHashes ?? [:]
        newCacheValue[contactHash] = valueForContactHash
        cachedContactPairsForContactHashes = newCacheValue

        return valueForContactHash
    }

    public func getValue(phoneNumber: PhoneNumber) -> ContactPair? {
        if let cachedContactPairsForPhoneNumbers,
           let cachedValue = cachedContactPairsForPhoneNumbers[phoneNumber.compiledNumberString] {
            return cachedValue
        }

        guard let valueForPhoneNumber = archive
            .first(where: { $0.contact.phoneNumbers.map(\.compiledNumberString).contains(phoneNumber.compiledNumberString)
            }) else { return nil }

        var newCacheValue = cachedContactPairsForPhoneNumbers ?? [:]
        newCacheValue[phoneNumber.compiledNumberString] = valueForPhoneNumber
        cachedContactPairsForPhoneNumbers = newCacheValue

        return valueForPhoneNumber
    }

    public func getValue(userNumberHash: String) -> ContactPair? {
        if let cachedContactPairsForUserNumberHashes,
           let cachedValue = cachedContactPairsForUserNumberHashes[userNumberHash] {
            return cachedValue
        }

        guard let valueForUserNumberHash = archive
            .first(where: {
                (phoneNumberService.possibleHashes(for: $0.contact.phoneNumbers.compiledNumberStrings.unique) ?? []).contains(userNumberHash)
            }) else { return nil }

        var newCacheValue = cachedContactPairsForUserNumberHashes ?? [:]
        newCacheValue[userNumberHash] = valueForUserNumberHash
        cachedContactPairsForUserNumberHashes = newCacheValue

        return valueForUserNumberHash
    }

    // MARK: - Persist Values for Notification Extension

    private func persistValuesForNotificationExtension() {
        Task { @MainActor in
            var notificationExtensionArchive = [[String]: String]()

            archive.forEach { contactPair in
                let possibleHashes = phoneNumberService.possibleHashes(for: contactPair.contact.phoneNumbers.compiledNumberStrings.unique) ?? []
                notificationExtensionArchive[possibleHashes] = contactPair.contact.fullName
            }

            guard let encoded = try? jsonEncoder.encode(notificationExtensionArchive) else { return }
            appGroupDefaults.set(encoded, forKey: NotificationExtensionConstants.defaultsKeyName)
        }
    }
}
