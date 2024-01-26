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

public final class ContactPairArchiveService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    private var archive: [ContactPair]? {
        didSet { persistedArchive = archive }
    }

    @Persistent(.contactPairArchive) private var persistedArchive: [ContactPair]?

    // MARK: - Init

    public init() {
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
        archive?.first(where: { $0.contact.compressedHash == contactHash })
    }

    public func getValue(userNumberHash: String) -> ContactPair? {
        archive?
            .first(where: {
                (phoneNumberService.possibleHashes(for: $0.contact.phoneNumbers.compiledNumberStrings.unique) ?? []).contains(userNumberHash)
            })
    }
}
