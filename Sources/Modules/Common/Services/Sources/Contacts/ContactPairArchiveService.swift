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

/// Use ``ContactPairArchiveService`` to persist and query the archive of contact pairs known to
/// the app.
///
/// The archive associates the user's device contacts with the users registered under their
/// phone numbers. It is cached in memory, persisted across launches, and mirrored to shared
/// app-group storage so the notification extension can resolve contact names.
final class ContactPairArchiveService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case archive
        case contactPairsForPhoneNumbers
    }

    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities

    // MARK: - Properties

    @Cached(CacheKey.archive) private var cachedArchive: [ContactPair]?
    @Cached(CacheKey.contactPairsForPhoneNumbers) private var cachedContactPairsForPhoneNumbers: [String: ContactPair]?
    @Persistent(.contactPairArchive) private var persistedArchive: [ContactPair]?
    @SharedEvent(\.updatedContactPairArchive) private var updatedContactPairArchive

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

    /// Creates a contact pair archive service.
    ///
    /// Creating the service mirrors the current archive to shared app-group storage.
    init() {
        persistValuesForNotificationExtension()
    }

    // MARK: - Addition

    /// Adds the given contact pairs to the archive.
    ///
    /// Pairs already present in the archive are skipped; otherwise, any existing pair for the
    /// same contact identifier is replaced. Adding values clears the contact image cache and
    /// notifies observers that the archive changed.
    ///
    /// - Parameter contactPairs: The contact pairs to add.
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
        updatedContactPairArchive.send()
    }

    // MARK: - Removal

    /// Removes every contact pair from the archive.
    ///
    /// Clearing the archive also clears the contact image cache. Observers are not notified.
    func clearArchive() {
        archive = []
        cachedContactPairsForPhoneNumbers = nil
        coreUtilities.clearCaches([.contactImage])
    }

    // MARK: - Retrieval

    /// Returns the archived contact pair for the given phone number.
    ///
    /// Lookups match against each pair's compiled number strings and are memoized per phone
    /// number.
    ///
    /// - Parameter phoneNumber: The phone number for which to retrieve a contact pair.
    ///
    /// - Returns: The contact pair whose numbers include the given phone number; otherwise,
    ///   `nil` if no match exists.
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
        let archiveSnapshot = archive
        Task { @MainActor in
            @Dependency(\.appGroupDefaults) var appGroupDefaults: UserDefaults
            @Dependency(\.jsonEncoder) var jsonEncoder: JSONEncoder
            @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService

            var notificationExtensionArchive = [[String]: String]()
            for contactPair in archiveSnapshot {
                let possibleHashes = phoneNumberService.possibleHashes(
                    for: contactPair.compiledNumberStrings.unique
                ) ?? []

                notificationExtensionArchive[possibleHashes] = contactPair.contact.fullName
            }

            guard let encoded = try? jsonEncoder.encode(notificationExtensionArchive) else { return }

            appGroupDefaults.set(
                encoded,
                forKey: NotificationExtensionConstants.contactArchiveDefaultsKeyName
            )
        }
    }
}
