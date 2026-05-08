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

    let contactPairArchive: ContactPairArchiveService

    @Cached(CacheKey.cnContacts) var cachedCNContacts: [CNContact]?

    // MARK: - Init

    init(contactPairArchive: ContactPairArchiveService) {
        self.contactPairArchive = contactPairArchive
    }

    // MARK: - Sync Contact Pair Archive

    func syncContactPairArchive() async -> Exception? {
        let getAllUsersResult = await userService.getAllUsers()

        switch getAllUsersResult {
        case let .success(users):
            let fetchContactPairsResult = await fetchContactPairs(for: users)

            switch fetchContactPairsResult {
            case let .success(contactPairs):
                coreUtilities.clearCaches([
                    .contactPairArchive,
                    .conversationCellViewData,
                    .queriedContactPairs,
                    .user,
                ])

                @Persistent(.unknownContactPairArchive) var unknownContactPairArchive: [ContactPair]?
                services.contact.contactPairArchive.addValues(contactPairs)
                unknownContactPairArchive = (unknownContactPairArchive ?? []) + users
                    .filter { !contactPairs.users.map(\.id).contains($0.id) }
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
                return nil

            case let .failure(exception):
                guard !exception.isEqual(to: .emptyContactList) else { return nil }
                return exception
            }

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Clear Cache

    func clearCache() {
        cachedCNContacts = nil
    }

    // MARK: - Auxiliary

    @MainActor
    private func fetchContactPairs(for users: [User]) async -> Callback<[ContactPair], Exception> {
        await withCheckedContinuation { continuation in
            fetchContactPairsWithCompletion(for: users) { callback in
                continuation.resume(returning: callback)
            }
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
                        numberPairs: [.init(phoneNumber: user.phoneNumber, users: [user])]
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
