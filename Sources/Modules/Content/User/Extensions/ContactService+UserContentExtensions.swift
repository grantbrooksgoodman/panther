//
//  ContactService+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation

/* Proprietary */
import AppSubsystem

public extension ContactService {
    func firstCNContact(
        for phoneNumber: PhoneNumber,
        returnForEmptyCachedCNContacts: Bool = false
    ) async -> Callback<CNContact, Exception> {
        @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService
        let commonParams = ["PhoneNumber": phoneNumber.encoded]

        guard let cachedCNContacts,
              !cachedCNContacts.isEmpty else {
            guard !returnForEmptyCachedCNContacts else {
                return .failure(.init(
                    "Empty contact list.",
                    metadata: [self, #file, #function, #line]
                ).appending(extraParams: commonParams))
            }

            if let exception = await syncContactPairArchive() {
                return .failure(exception.appending(extraParams: commonParams))
            }

            return await firstCNContact(for: phoneNumber, returnForEmptyCachedCNContacts: true)
        }

        func satisfiesConstraints(_ contact: Contact) -> Bool {
            let numberStrings = contact.phoneNumbers.compiledNumberStrings
            guard let callingCodes = phoneNumberService.possibleCallingCodes(for: numberStrings),
                  let hashes = phoneNumberService.possibleHashes(for: numberStrings),
                  callingCodes.contains(phoneNumber.callingCode),
                  hashes.contains(phoneNumber.compiledNumberString.encodedHash) else { return false }
            return true
        }

        guard let match = cachedCNContacts.first(where: { satisfiesConstraints(.init($0)) }) else {
            return .failure(.init(
                "No contacts found for provided phone number.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(match)
    }
}
