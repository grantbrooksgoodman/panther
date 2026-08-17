//
//  ContactService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import ContactsUI
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/// Use ``ContactService`` to match the user's device contacts with registered users.
///
/// The service queries the device's contact store for contacts whose phone numbers belong to
/// registered users, maintains the contact pair archive with the results, and caches the
/// fetched contacts in memory.
final class ContactService: @unchecked Sendable {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case cnContacts
    }

    // MARK: - Dependencies

    @Dependency(\.cnContactStore) private var cnContactStore: CNContactStore
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.userService) private var userService: UserService

    // MARK: - Properties

    /// The service that persists and queries the contact pair archive.
    let contactPairArchive: ContactPairArchiveService

    /// The Contacts framework contacts matched during archive syncs.
    @Cached(CacheKey.cnContacts) var cachedCNContacts: [CNContact]?

    private static let coalescer = SingleSlotCoalescer<Void>()

    // MARK: - Init

    /// Creates a contact service with the given archive service.
    ///
    /// - Parameter contactPairArchive: The service that persists and queries the contact pair
    ///   archive.
    init(contactPairArchive: ContactPairArchiveService) {
        self.contactPairArchive = contactPairArchive
    }

    // MARK: - Sync Contact Pair Archive

    /// Rebuilds the contact pair archive by matching every registered user against the device's
    /// contacts.
    ///
    /// This method fetches all registered users, queries the device's contact store for
    /// contacts matching their phone numbers, and replaces the archive's contents with the
    /// results. Users without a matching device contact are persisted separately to the unknown
    /// contact pair archive. Related caches are cleared before the archive is repopulated.
    ///
    /// If no device contact matches any registered user, this method returns without modifying
    /// the archive.
    ///
    /// Concurrent calls coalesce onto a single in-flight sync.
    ///
    /// - Throws: An `Exception` if contact permission has not been granted, or if fetching
    ///   users or contacts fails.
    func syncContactPairArchive() async throws(Exception) {
        try await Self.coalescer { [weak self] () async throws(Exception) in
            guard let self else {
                throw Exception(
                    "Service has been deallocated.",
                    metadata: .init(sender: Self.self)
                )
            }

            try await _syncContactPairArchive()
        }
    }

    private func _syncContactPairArchive() async throws(Exception) {
        do {
            let users = try await userService.getAllUsers()
            let contactPairs = try await fetchContactPairs(
                for: users
            )

            coreUtilities.clearCaches([
                .conversationCellViewData,
                .queriedContactPairs,
            ])

            services.contact.contactPairArchive.clearArchive()

            @Persistent(.unknownContactPairArchive) var unknownContactPairArchive: [ContactPair]?
            services.contact.contactPairArchive.addValues(contactPairs)

            let contactPairUserIDs = contactPairs.userIDs
            unknownContactPairArchive = users
                .filter { !contactPairUserIDs.contains($0.id) }
                .map {
                    ContactPair.withUser(
                        $0,
                        name: $0.displayName
                    )
                }

            Logger.log(
                "Successfully updated contact pair archive.",
                domain: .contacts,
                sender: self
            )
        } catch {
            guard !error.isEqual(
                to: .emptyContactList
            ) else { return }
            throw error
        }
    }

    // MARK: - Clear Cache

    /// Removes every cached Contacts framework contact.
    func clearCache() {
        cachedCNContacts = nil
    }

    // MARK: - Auxiliary

    @MainActor
    private func fetchContactPairs(
        for users: [User]
    ) async throws(Exception) -> [ContactPair] {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                fetchContactPairsWithCompletion(for: users) { callback in
                    switch callback {
                    case let .success(contactPairs):
                        continuation.resume(returning: contactPairs)

                    case let .failure(exception):
                        continuation.resume(throwing: exception)
                    }
                }
            }
        } catch {
            guard let exception = error as? Exception else {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }

            throw exception
        }
    }

    @MainActor
    private func fetchContactPairsWithCompletion(
        for users: [User],
        completion: @escaping (_ callback: Callback<[ContactPair], Exception>) -> Void
    ) {
        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        guard services.permission.contactPermissionStatus == .granted else {
            guard canComplete else { return }
            return completion(.failure(.init(
                "Not authorized for contacts.",
                isReportable: false,
                metadata: .init(sender: self)
            )))
        }

        guard let queryKeys = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactNicknameKey,
            CNContactOrganizationNameKey,
            CNContactPhoneNumbersKey,
            CNContactPhoneticFamilyNameKey,
            CNContactPhoneticGivenNameKey,
            CNContactPhoneticOrganizationNameKey,
            CNContactThumbnailImageDataKey,
            CNContactViewController.descriptorForRequiredKeys(),
        ] as? [CNKeyDescriptor] else {
            guard canComplete else { return }
            return completion(.failure(.init(
                "Failed to synthesize query keys.",
                metadata: .init(sender: self)
            )))
        }

        var contactPairs = [ContactPair]()
        for user in users {
            do {
                let predicates = [
                    CNContact.predicateForContacts(matching: .init(stringValue: user.phoneNumber.compiledNumberString)),
                    CNContact.predicateForContacts(matching: .init(stringValue: "+\(user.phoneNumber.compiledNumberString)")),
                ]

                var matchingContacts = [CNContact]()
                try predicates.forEach {
                    try matchingContacts.append(contentsOf: cnContactStore.unifiedContacts(
                        matching: $0,
                        keysToFetch: queryKeys
                    ))
                }

                matchingContacts = matchingContacts.unique
                guard !matchingContacts.isEmpty else { continue }

                var cachedCNContacts = cachedCNContacts ?? []
                cachedCNContacts.append(contentsOf: matchingContacts)
                self.cachedCNContacts = cachedCNContacts.unique

                contactPairs.append(contentsOf: matchingContacts.reduce(into: []) { partialResult, cnContact in
                    let contactPair = ContactPair(
                        contact: .init(cnContact),
                        numberPairs: [.init(
                            phoneNumber: user.phoneNumber,
                            userIDs: [user.id]
                        )]
                    )

                    if let existingIndex = partialResult.firstIndex(where: { $0.contact == contactPair.contact }),
                       let existingPair = partialResult.itemAt(existingIndex) {
                        partialResult[existingIndex] = .init(
                            contact: contactPair.contact,
                            numberPairs: (existingPair.numberPairs + contactPair.numberPairs)
                                .unique
                                .sorted(by: { $0.phoneNumber.callingCode < $1.phoneNumber.callingCode })
                        )
                    } else {
                        partialResult.append(contactPair)
                    }
                })
            } catch {
                guard canComplete else { return }
                completion(.failure(.init(error, metadata: .init(sender: self))))
            }
        }

        guard !contactPairs.isEmpty else {
            guard canComplete else { return }
            completion(.failure(.init(
                "Empty contact list.",
                isReportable: false,
                metadata: .init(sender: self)
            )))
            return
        }

        guard canComplete else { return }
        completion(.success(
            contactPairs
                .unique
                .sorted(by: { $0.contact.firstName < $1.contact.firstName })
                .uniquedByPhoneNumber
        ))
    }
}
