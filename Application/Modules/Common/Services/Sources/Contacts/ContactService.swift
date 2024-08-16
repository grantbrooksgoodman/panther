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

/* 3rd-party */
import CoreArchitecture

public final class ContactService {
    // MARK: - Types

    public enum CacheKey: String, CaseIterable {
        case cnContacts
        case contacts
    }

    // MARK: - Dependencies

    @Dependency(\.cnContactStore) private var cnContactStore: CNContactStore
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.userInteractiveQOSQueue) private var userInteractiveQOSQueue: DispatchQueue

    // MARK: - Properties

    public let contactPairArchive: ContactPairArchiveService
    public let sync: ContactSyncService

    @Cached(CacheKey.cnContacts) public var cachedCNContacts: [CNContact]?

    @Cached(CacheKey.contacts) private var cachedContacts: [Contact]?

    // MARK: - Init

    public init(
        contactPairArchive: ContactPairArchiveService,
        sync: ContactSyncService
    ) {
        self.contactPairArchive = contactPairArchive
        self.sync = sync
    }

    // MARK: - Fetch All Contacts

    public func fetchAllContacts(cacheStrategy: CacheStrategy = .returnCacheFirst) async -> Callback<[Contact], Exception> {
        return await withCheckedContinuation { continuation in
            fetchAllContactsWithCompletion(cacheStrategy: cacheStrategy) { callback in
                continuation.resume(returning: callback)
            }
        }
    }

    private func fetchAllContactsWithCompletion(
        cacheStrategy: CacheStrategy,
        completion: @escaping (_ callback: Callback<[Contact], Exception>) -> Void
    ) {
        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        func completeWithCacheIfPresent() {
            guard let cachedContacts,
                  !cachedContacts.isEmpty,
                  canComplete else { return }
            completion(.success(cachedContacts))
        }

        if cacheStrategy == .returnCacheFirst {
            completeWithCacheIfPresent()
        }

        guard services.permission.contactPermissionStatus == .granted else {
            if cacheStrategy == .returnCacheOnFailure {
                completeWithCacheIfPresent()
            }

            guard canComplete else { return }
            completion(.failure(.init("Not authorized for contacts.", metadata: [self, #file, #function, #line])))
            return
        }

        var cnContacts = [CNContact]()
        var contacts = [Contact]()

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
            if cacheStrategy == .returnCacheOnFailure {
                completeWithCacheIfPresent()
            }

            guard canComplete else { return }
            completion(.failure(.init("Failed to synthesize query keys.", metadata: [self, #file, #function, #line])))
            return
        }

        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys)

        userInteractiveQOSQueue.async {
            do {
                try self.cnContactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                    if !contact.phoneNumbers.isEmpty {
                        cnContacts.append(contact)
                        contacts.append(.init(contact))
                    }
                }
            } catch {
                if cacheStrategy == .returnCacheOnFailure {
                    completeWithCacheIfPresent()
                }

                guard canComplete else { return }
                completion(.failure(.init(error, metadata: [self, #file, #function, #line])))
            }

            guard !contacts.isEmpty else {
                if cacheStrategy == .returnCacheOnFailure {
                    completeWithCacheIfPresent()
                }

                guard canComplete else { return }
                completion(.failure(.init("Empty contact list.", metadata: [self, #file, #function, #line])))
                return
            }

            contacts = contacts.sorted { $0.firstName < $1.firstName }
            self.cachedCNContacts = cnContacts
            self.cachedContacts = contacts

            guard canComplete else { return }
            completion(.success(contacts))
        }
    }

    // MARK: - Fetch Contacts by Phone Number

    public func fetchContacts(by phoneNumber: PhoneNumber) async -> Callback<[Contact], Exception> {
        guard let cachedContacts,
              !cachedContacts.isEmpty else {
            let fetchAllContactsResult = await fetchAllContacts()

            switch fetchAllContactsResult {
            case .success:
                return await fetchContacts(by: phoneNumber)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        func satisfiesConstraints(_ contact: Contact) -> Bool {
            let numberStrings = contact.phoneNumbers.compiledNumberStrings
            guard let callingCodes = services.phoneNumber.possibleCallingCodes(for: numberStrings),
                  let hashes = services.phoneNumber.possibleHashes(for: numberStrings),
                  callingCodes.contains(phoneNumber.callingCode),
                  hashes.contains(phoneNumber.compiledNumberString.encodedHash) else { return false }
            return true
        }

        let matches = cachedContacts.filter { satisfiesConstraints($0) }
        guard !matches.isEmpty else {
            return .failure(.init(
                "No contacts match the given phone number.",
                extraParams: ["Contacts": cachedContacts,
                              "PhoneNumber": phoneNumber.compiledNumberString],
                metadata: [self, #file, #function, #line]
            ))
        }

        return .success(matches)
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cachedCNContacts = nil
        cachedContacts = nil
    }
}
