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
import Redux

public final class ContactSyncService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    @Persistent(.mismatchedHashes) private var mismatchedHashes: [String]?
    @Persistent(.localUserHashes) private var persistedLocalUserHashes: [String]?
    @Persistent(.serverUserHashes) private var persistedServerUserHashes: [String]?

    // MARK: - Synchronization

    public func syncContactPairArchive() async -> Exception? {
        let syncHashesResult = await syncHashes()

        switch syncHashesResult {
        case let .success(shouldUpdate):
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
        let getLocalUserHashesResult = await getLocalUserHashes()

        switch getLocalUserHashesResult {
        case let .success(localUserHashes):
            guard let persistedLocalUserHashes,
                  persistedLocalUserHashes.sorted() == localUserHashes.sorted() else {
                if let exception = await updatePersistedLocalUserHashes(with: localUserHashes) {
                    return .failure(exception)
                }
                return .success(true)
            }

            let getServerUserHashesResult = await getServerUserHashes()

            switch getServerUserHashesResult {
            case let .success(serverUserHashes):
                guard let persistedServerUserHashes,
                      persistedServerUserHashes.sorted() == serverUserHashes.sorted() else {
                    if let exception = await updatePersistedServerUserHashes(with: serverUserHashes) {
                        return .failure(exception)
                    }
                    return .success(true)
                }

                var filteredHashes = serverUserHashes.filter { persistedLocalUserHashes.contains($0) }
                if let mismatchedHashes {
                    filteredHashes = filteredHashes.filter { !mismatchedHashes.contains($0) }
                }

                let archivedContactCount = filteredHashes.reduce(into: Int()) { partialResult, hash in
                    partialResult += services.contact.contactPairArchive.getValue(userHash: hash) != nil ? 1 : 0
                }

                let missingValues = filteredHashes.filter { services.contact.contactPairArchive.getValue(userHash: $0) == nil }
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
            let needingFetch = contacts.filter { services.contact.contactPairArchive.getValue(contactHash: $0.compressedHash) == nil }

            guard !needingFetch.isEmpty else {
                Logger.log(
                    "Contact pair archive is already up to date.",
                    domain: .contacts,
                    metadata: [self, #file, #function, #line]
                )
                return nil
            }

            for contact in needingFetch {
                let getUsersResult = await networking.services.user.getUsers(phoneNumbers: contact.phoneNumbers)

                switch getUsersResult {
                case let .success(numberPairs):
                    services.contact.contactPairArchive.addValue(.init(contact: contact, numberPairs: numberPairs))

                case let .failure(exception):
                    if !exception.isEqual(toAny: [
                        .noUsersWithPhoneNumbers,
                        .noUserWithHashes,
                        .noValueExists,
                    ]) {
                        return exception
                    }
                }
            }

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

    private func getLocalUserHashes() async -> Callback<[String], Exception> {
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

    private func getServerUserHashes() async -> Callback<[String], Exception> {
        let getValuesResult = await networking.database.getValues(at: networking.config.paths.userHashes)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.init(
                    "Failed to typecast values to dictionary.",
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

    private func updatePersistedLocalUserHashes(with value: [String]? = nil) async -> Exception? {
        guard let value,
              !value.isEmpty else {
            let getLocalUserHashesResult = await getLocalUserHashes()

            switch getLocalUserHashesResult {
            case let .success(localUserHashes):
                persistedLocalUserHashes = localUserHashes
            case let .failure(exception):
                return exception
            }

            return nil
        }

        persistedLocalUserHashes = value
        return nil
    }

    private func updatePersistedServerUserHashes(with value: [String]? = nil) async -> Exception? {
        guard let value,
              !value.isEmpty else {
            let getServerUserHashesResult = await getServerUserHashes()

            switch getServerUserHashesResult {
            case let .success(serverUserHashes):
                persistedServerUserHashes = serverUserHashes
            case let .failure(exception):
                return exception
            }

            return nil
        }

        persistedServerUserHashes = value
        return nil
    }
}
