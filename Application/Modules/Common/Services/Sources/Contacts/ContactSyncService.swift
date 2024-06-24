//
//  ContactSyncService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct ContactSyncService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    @Persistent(.mismatchedHashes) private var mismatchedHashes: [String]?
    @Persistent(.localUserNumberHashes) private var persistedLocalUserNumberHashes: [String]?
    @Persistent(.serverUserNumberHashes) private var persistedServerUserNumberHashes: [String]?

    // MARK: - Synchronization

    public func syncContactPairArchive(forceUpdate: Bool = false) async -> Exception? {
        let syncHashesResult = await syncHashes()

        switch syncHashesResult {
        case let .success(shouldUpdate):
            if forceUpdate {
                Logger.log(
                    "Performing forced update of contact pair archive.",
                    domain: .contacts,
                    metadata: [self, #file, #function, #line]
                )
                services.contact.contactPairArchive.clearArchive()
                return await updateContactPairArchive()
            }

            guard shouldUpdate else { return nil }

            Logger.log(
                "Contact pair archive needs updating.",
                domain: .contacts,
                metadata: [self, #file, #function, #line]
            )
            return await updateContactPairArchive()
        case let .failure(exception):
            return exception
        }
    }

    /// - Returns: A `Bool` describing whether or not the local contact archive needs updating.
    private func syncHashes() async -> Callback<Bool, Exception> {
        let getLocalUserNumberHashesResult = await getLocalUserNumberHashes()

        switch getLocalUserNumberHashesResult {
        case let .success(localUserNumberHashes):
            guard let persistedLocalUserNumberHashes,
                  persistedLocalUserNumberHashes.sorted() == localUserNumberHashes.sorted() else {
                if let exception = await updatePersistedLocalUserNumberHashes(with: localUserNumberHashes) {
                    return .failure(exception)
                }
                return .success(true)
            }

            let getServerUserNumberHashesResult = await getServerUserNumberHashes()

            switch getServerUserNumberHashesResult {
            case let .success(serverUserNumberHashes):
                guard let persistedServerUserNumberHashes,
                      persistedServerUserNumberHashes.sorted() == serverUserNumberHashes.sorted() else {
                    if let exception = await updatePersistedServerUserNumberHashes(with: serverUserNumberHashes) {
                        return .failure(exception)
                    }
                    return .success(true)
                }

                var filteredHashes = serverUserNumberHashes.filter { persistedLocalUserNumberHashes.contains($0) }
                if let mismatchedHashes {
                    filteredHashes = filteredHashes.filter { !mismatchedHashes.contains($0) }
                }

                let archivedContactCount = filteredHashes.reduce(into: Int()) { partialResult, hash in
                    partialResult += services.contact.contactPairArchive.getValue(userNumberHash: hash) != nil ? 1 : 0
                }

                let missingValues = filteredHashes.filter { services.contact.contactPairArchive.getValue(userNumberHash: $0) == nil }
                if !missingValues.isEmpty {
                    Logger.log(
                        "Missing the following contact values:\n\(missingValues)",
                        domain: .contacts,
                        metadata: [self, #file, #function, #line]
                    )
                }

                guard !filteredHashes.isEmpty else {
                    return .success(true)
                }

                return .success(archivedContactCount != filteredHashes.count)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func updateContactPairArchive() async -> Exception? {
        let fetchAllContactsResult = await services.contact.fetchAllContacts()

        switch fetchAllContactsResult {
        case let .success(contacts):
            let needingFetch = contacts.filter { services.contact.contactPairArchive.getValue(contactHash: $0.encodedHash) == nil }

            guard !needingFetch.isEmpty else {
                Logger.log(
                    "Contact pair archive is already up to date.",
                    domain: .contacts,
                    metadata: [self, #file, #function, #line]
                )
                return nil
            }

            var contactPairs = [ContactPair]()
            for contact in needingFetch {
                let getUsersResult = await networking.services.user.getUsers(phoneNumbers: contact.phoneNumbers)

                switch getUsersResult {
                case let .success(numberPairs):
                    contactPairs.append(.init(contact: contact, numberPairs: numberPairs))

                case let .failure(exception):
                    let possibleHashes = services.phoneNumber.possibleHashes(for: contact.phoneNumbers.compiledNumberStrings.unique) ?? []
                    services.contact.contactPairArchive.removeValue(userNumberHashes: possibleHashes)

                    if !exception.isEqual(toAny: [
                        .mismatchedHashAndCallingCode,
                        .noUsersWithPhoneNumbers,
                        .noUserWithHashes,
                        .noValueExists,
                    ]) {
                        return exception
                    }
                }
            }

            services.contact.contactPairArchive.addValues(contactPairs)
            Logger.log(
                "Successfully updated contact pair archive.",
                domain: .contacts,
                metadata: [self, #file, #function, #line]
            )

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Hash Retrieval

    private func getLocalUserNumberHashes() async -> Callback<[String], Exception> {
        let fetchAllContactsResult = await services.contact.fetchAllContacts(cacheStrategy: .disregardCache)

        switch fetchAllContactsResult {
        case let .success(contacts):
            return .success(contacts.reduce(into: [String]()) { partialResult, contact in
                if let possibleHashes = services.phoneNumber.possibleHashes(for: contact.phoneNumbers.compiledNumberStrings),
                   !possibleHashes.isEmpty {
                    partialResult.append(contentsOf: possibleHashes)
                }
            })

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getServerUserNumberHashes() async -> Callback<[String], Exception> {
        let getValuesResult = await networking.database.getValues(at: networking.config.paths.userNumberHashes)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.typecastFailed(
                    "dictionary",
                    extraParams: ["Values": values],
                    metadata: [self, #file, #function, #line]
                ))
            }

            return .success(.init(dictionary.keys))
        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Persisted Hash Updating

    private func updatePersistedLocalUserNumberHashes(with value: [String]? = nil) async -> Exception? {
        guard let value,
              !value.isEmpty else {
            let getLocalUserNumberHashesResult = await getLocalUserNumberHashes()

            switch getLocalUserNumberHashesResult {
            case let .success(localUserNumberHashes):
                persistedLocalUserNumberHashes = localUserNumberHashes
            case let .failure(exception):
                return exception
            }

            return nil
        }

        persistedLocalUserNumberHashes = value
        return nil
    }

    private func updatePersistedServerUserNumberHashes(with value: [String]? = nil) async -> Exception? {
        guard let value,
              !value.isEmpty else {
            let getServerUserNumberHashesResult = await getServerUserNumberHashes()

            switch getServerUserNumberHashesResult {
            case let .success(serverUserNumberHashes):
                persistedServerUserNumberHashes = serverUserNumberHashes
            case let .failure(exception):
                return exception
            }

            return nil
        }

        persistedServerUserNumberHashes = value
        return nil
    }
}
