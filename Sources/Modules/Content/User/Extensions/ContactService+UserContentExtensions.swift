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

    /// A Boolean value that indicates whether the contact pair archive contains any contacts
    /// besides the current user.
    var hasContactsBesidesCurrentUser: Bool {
        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        guard let contactPairArchive,
              !contactPairArchive.isEmpty else { return false }
        return !contactPairArchive.filter { !$0.containsCurrentUser }.isEmpty
    }

    // MARK: - Methods

    /// Returns the first system contact matching the given phone number.
    ///
    /// When no contacts are cached, this method synchronizes the contact pair archive and
    /// retries once.
    ///
    /// - Parameters:
    ///   - phoneNumber: The phone number to match.
    ///   - returnForEmptyCachedCNContacts: A Boolean value that determines whether to throw,
    ///     rather than synchronize and retry, when no contacts are cached.
    ///
    /// - Returns: The first system contact matching the phone number.
    ///
    /// - Throws: An `Exception` if no matching contact is found or synchronization fails.
    func firstCNContact(
        for phoneNumber: PhoneNumber,
        returnForEmptyCachedCNContacts: Bool = false
    ) async throws(Exception) -> CNContact {
        @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService
        let userInfo = ["PhoneNumber": phoneNumber.encoded]

        guard let cachedCNContacts,
              !cachedCNContacts.isEmpty else {
            guard !returnForEmptyCachedCNContacts else {
                throw Exception(
                    "Empty contact list.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ).appending(userInfo: userInfo)
            }

            do {
                try await syncContactPairArchive()
            } catch {
                throw error.appending(userInfo: userInfo)
            }

            return try await firstCNContact(
                for: phoneNumber,
                returnForEmptyCachedCNContacts: true
            )
        }

        func satisfiesConstraints(_ contact: Contact) -> Bool {
            let numberStrings = contact.phoneNumbers.compiledNumberStrings
            guard let callingCodes = phoneNumberService.possibleCallingCodes(for: numberStrings),
                  let hashes = phoneNumberService.possibleHashes(for: numberStrings),
                  callingCodes.contains(phoneNumber.callingCode),
                  hashes.contains(phoneNumber.compiledNumberString.encodedHash) else { return false }
            return true
        }

        guard let match = cachedCNContacts.first(where: {
            satisfiesConstraints(.init($0))
        }) else {
            throw Exception(
                "No contacts found for provided phone number.",
                isReportable: false,
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        return match
    }

    /// Synchronizes the contact pair archive when it is empty and contact permission has been
    /// granted.
    ///
    /// - Throws: An `Exception` if synchronization fails.
    static func syncIfNeeded() async throws(Exception) {
        @Dependency(\.commonServices) var services: CommonServices

        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        let isArchiveEmpty = contactPairArchive == nil ||
            contactPairArchive?.isEmpty == true ||
            !services.contact.hasContactsBesidesCurrentUser

        if isArchiveEmpty,
           services.permission.contactPermissionStatus == .granted {
            try await services.contact.syncContactPairArchive()
        }
    }
}
