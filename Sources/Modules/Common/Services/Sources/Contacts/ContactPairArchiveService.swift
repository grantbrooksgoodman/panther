//
//  ContactPairArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

final class ContactPairArchiveService: @unchecked Sendable {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case archive
        case contactPairsForPhoneNumbers
    }

    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    @Cached(CacheKey.archive) private var cachedArchive: [ContactPair]?
    @Cached(CacheKey.contactPairsForPhoneNumbers) private var cachedContactPairsForPhoneNumbers: [String: ContactPair]?
    @Persistent(.contactPairArchive) private var persistedArchive: [ContactPair]?

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

    init() {
        persistValuesForNotificationExtension()
    }

    // MARK: - Addition

    func addValues(_ contactPairs: [ContactPair]) {
        var values = archive

        for contactPair in contactPairs where !values.contains(contactPair) {
            values.removeAll(where: { $0.contact.id == contactPair.contact.id })
            values.append(contactPair)

            Logger.log(
                .init(
                    "Added contact pair to persisted archive.",
                    isReportable: false,
                    userInfo: [
                        "FullName": contactPair.contact.fullName,
                        "PhoneNumbers": contactPair.numberPairs.map { $0.phoneNumber.formattedString() }.description,
                    ],
                    metadata: .init(sender: self)
                ),
                domain: .contacts
            )
        }

        archive = values
        cachedContactPairsForPhoneNumbers = cachedContactPairsForPhoneNumbers?.filter { !contactPairs.contains($0.value) }

        coreUtilities.clearCaches([.contactImage])
        Observables.updatedContactPairArchive.trigger()
    }

    // MARK: - Removal

    func clearArchive() {
        archive = []
        cachedContactPairsForPhoneNumbers = nil
        coreUtilities.clearCaches([.contactImage])
    }

    // MARK: - Retrieval

    func getValue(phoneNumber: PhoneNumber) -> ContactPair? {
        if let cachedContactPairsForPhoneNumbers,
           let cachedValue = cachedContactPairsForPhoneNumbers[phoneNumber.compiledNumberString] {
            return cachedValue
        }

        guard let valueForPhoneNumber = archive
            .first(where: {
                $0.compiledNumberStrings.contains(phoneNumber.compiledNumberString)
            }) else { return nil }

        var newCacheValue = cachedContactPairsForPhoneNumbers ?? [:]
        newCacheValue[phoneNumber.compiledNumberString] = valueForPhoneNumber
        cachedContactPairsForPhoneNumbers = newCacheValue

        return valueForPhoneNumber
    }

    // MARK: - Persist Values for Notification Extension

    private func persistValuesForNotificationExtension() {
        Task { @MainActor in
            var notificationExtensionArchive = [[String]: String]()

            archive.forEach { contactPair in
                let possibleHashes = phoneNumberService.possibleHashes(
                    for: contactPair.compiledNumberStrings.unique
                ) ?? []

                notificationExtensionArchive[possibleHashes] = contactPair.contact.fullName
            }

            guard let encoded = try? jsonEncoder.encode(notificationExtensionArchive) else { return }
            appGroupDefaults.set(encoded, forKey: NotificationExtensionConstants.contactArchiveDefaultsKeyName)
        }
    }
}
