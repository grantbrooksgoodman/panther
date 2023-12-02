//
//  ContactService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation

/* 3rd-party */
import Redux

public final class ContactService: Cacheable {
    // MARK: - Types

    public enum CacheStrategy {
        case disregardCache
        case returnCacheFirst
        case returnCacheOnFailure
    }

    // MARK: - Dependencies

    @Dependency(\.cnContactStore) private var cnContactStore: CNContactStore
    @Dependency(\.contactNameService) private var contactNameService: ContactNameService
    @Dependency(\.permissionService) private var permissionService: PermissionService
    @Dependency(\.userInteractiveQOSQueue) private var userInteractiveQOSQueue: DispatchQueue

    // MARK: - Properties

    public let emptyCache: Cache
    public var cache: Cache

    // MARK: - Init

    public init() {
        emptyCache = .init(
            [
                .contacts: [Contact](),
            ]
        )
        cache = emptyCache
    }

    // MARK: - Methods

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
            guard let cachedValue = cache.value(forKey: .contacts) as? [Contact],
                  !cachedValue.isEmpty,
                  canComplete else { return }
            completion(.success(cachedValue))
        }

        if cacheStrategy == .returnCacheFirst {
            completeWithCacheIfPresent()
        }

        guard permissionService.contactPermissionStatus == .granted else {
            if cacheStrategy == .returnCacheOnFailure {
                completeWithCacheIfPresent()
            }

            guard canComplete else { return }
            completion(.failure(.init("Not authorized for contacts.", metadata: [self, #file, #function, #line])))
            return
        }

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
                        let compiledName = self.contactNameService.name(for: contact)
                        contacts.append(.init(
                            firstName: compiledName.firstName,
                            lastName: compiledName.lastName,
                            phoneNumbers: contact.phoneNumbers.asPhoneNumbers,
                            imageData: contact.thumbnailImageData
                        ))
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
            self.cache.set(contacts, forKey: .contacts)

            guard canComplete else { return }
            completion(.success(contacts))
        }
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum ContactServiceCacheDomainKey: String, Equatable {
        case contacts
    }
}

private extension Cache {
    convenience init(_ objects: [CacheDomain.ContactServiceCacheDomainKey: Any]) {
        var mappedObjects = [CacheDomain: Any]()
        objects.forEach { object in
            mappedObjects[.contactService(object.key)] = object.value
        }
        self.init(mappedObjects)
    }

    func set(_ value: Any, forKey key: CacheDomain.ContactServiceCacheDomainKey) {
        set(value, forKey: .contactService(key))
    }

    func value(forKey key: CacheDomain.ContactServiceCacheDomainKey) -> Any? {
        value(forKey: .contactService(key))
    }
}

/* MARK: ContactNameService Dependency */

private enum ContactNameServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ContactNameService {
        .init()
    }
}

private extension DependencyValues {
    var contactNameService: ContactNameService {
        get { self[ContactNameServiceDependency.self] }
        set { self[ContactNameServiceDependency.self] = newValue }
    }
}
