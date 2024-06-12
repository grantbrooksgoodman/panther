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
    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    private var archive: [ContactPair]? {
        didSet {
            persistedArchive = archive
            persistValuesForNotificationExtension()
        }
    }

    @Persistent(.contactPairArchive) private var persistedArchive: [ContactPair]?

    // MARK: - Init

    public init() {
        archive = persistedArchive
        persistValuesForNotificationExtension()
    }

    // MARK: - Addition

    public func addValues(_ contactPairs: [ContactPair]) {
        var values = archive ?? .init()

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
        Observables.updatedContactPairArchive.trigger()
    }

    // MARK: - Removal

    public func clearArchive() {
        archive = nil
    }

    public func removeValue(userNumberHashes: [String]) {
        func satisfiesConstraints(_ contactPair: ContactPair) -> Bool {
            let possibleHashes = phoneNumberService.possibleHashes(for: contactPair.contact.phoneNumbers.compiledNumberStrings.unique) ?? []
            return possibleHashes.containsAnyString(in: userNumberHashes)
        }

        guard (archive ?? []).contains(where: { satisfiesConstraints($0) }) else { return }
        archive?.removeAll(where: { satisfiesConstraints($0) })
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
        archive?.first(where: { $0.contact.encodedHash == contactHash })
    }

    public func getValue(phoneNumber: PhoneNumber) -> ContactPair? {
        archive?
            .first(where: { $0.contact.phoneNumbers.map(\.compiledNumberString).contains(phoneNumber.compiledNumberString) })
    }

    public func getValue(userNumberHash: String) -> ContactPair? {
        archive?
            .first(where: {
                (phoneNumberService.possibleHashes(for: $0.contact.phoneNumbers.compiledNumberStrings.unique) ?? []).contains(userNumberHash)
            })
    }

    // MARK: - Persist Values for Notification Extension

    private func persistValuesForNotificationExtension() {
        Task { @MainActor in
            var notificationExtensionArchive = [[String]: String]()

            archive?.forEach { contactPair in
                let possibleHashes = phoneNumberService.possibleHashes(for: contactPair.contact.phoneNumbers.compiledNumberStrings.unique) ?? []
                notificationExtensionArchive[possibleHashes] = contactPair.contact.fullName
            }

            guard let encoded = try? jsonEncoder.encode(notificationExtensionArchive) else { return }
            appGroupDefaults.set(encoded, forKey: NotificationExtensionConstants.defaultsKeyName)
        }
    }
}
