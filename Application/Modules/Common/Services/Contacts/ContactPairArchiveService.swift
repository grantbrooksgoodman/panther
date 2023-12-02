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

public struct ContactPairArchiveService {
    // MARK: - Dependencies

    @Dependency(\.phoneNumberService) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    @Persistent(.contactPairArchive) private var archive: [ContactPair]?

    // MARK: - Addition

    public func addValue(_ contactPair: ContactPair) {
        var values = archive ?? .init()

        values.removeAll(where: { $0.contact.compressedHash == contactPair.contact.compressedHash })
        values.append(contactPair)
        archive = values

        Logger.log(.init(
            "Added contact pair to local archive.",
            extraParams: ["FullName": contactPair.contact.fullName,
                          "PhoneNumber": contactPair.numberPairs?.first?.phoneNumber.compiledNumberString.phoneNumberFormatted ?? ""],
            metadata: [self, #file, #function, #line]
        ))
    }

    // MARK: - Retrieval

    public func getValue(contactHash: String) -> ContactPair? {
        archive?.first(where: { $0.contact.compressedHash == contactHash })
    }

    public func getValue(phoneNumbers: [String]) -> ContactPair? {
        archive?
            .filter { $0.contact.phoneNumbers.compiledNumberStrings.containsAnyString(in: phoneNumbers) }
            .first
    }

    public func getValue(userHash: String) -> ContactPair? {
        archive?
            .filter { phoneNumberService.possibleHashes(for: $0.contact.phoneNumbers.compiledNumberStrings.unique).contains(userHash) }
            .first
    }
}
