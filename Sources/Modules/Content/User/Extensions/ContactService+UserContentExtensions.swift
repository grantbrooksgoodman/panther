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

extension ContactService {
    // MARK: - Properties

    var hasContactsBesidesCurrentUser: Bool {
        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        guard let contactPairArchive,
              !contactPairArchive.isEmpty else { return true }
        return !contactPairArchive.filter { !$0.containsCurrentUser }.isEmpty
    }

    // MARK: - Methods

    func firstCNContact(
        for phoneNumber: PhoneNumber,
        returnForEmptyCachedCNContacts: Bool = false
    ) async -> Callback<CNContact, Exception> {
        @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService
        let userInfo = ["PhoneNumber": phoneNumber.encoded]

        guard let cachedCNContacts,
              !cachedCNContacts.isEmpty else {
            guard !returnForEmptyCachedCNContacts else {
                return .failure(.init(
                    "Empty contact list.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ).appending(userInfo: userInfo))
            }

            if let exception = await syncContactPairArchive() {
                return .failure(exception.appending(userInfo: userInfo))
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
                isReportable: false,
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo))
        }

        return .success(match)
    }

    static func populateValuesIfNeeded() async -> Exception? {
        @Dependency(\.commonServices) var services: CommonServices

        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        if contactPairArchive == nil || contactPairArchive?.isEmpty == true,
           services.permission.contactPermissionStatus == .granted,
           let exception = await services.contact.syncContactPairArchive() {
            return exception
        }

        return nil
    }
}
