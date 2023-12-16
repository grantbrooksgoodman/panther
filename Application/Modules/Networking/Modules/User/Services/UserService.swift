//
//  UserService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public final class UserService: Cacheable {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService
    @Dependency(\.commonServices.userSession) private var userSessionService: UserSessionService

    // MARK: - Properties

    // Instance
    public let legacy: LegacyUserService

    // Cache
    public let emptyCache: Cache
    public var cache: Cache

    // MARK: - Init

    public init(legacy: LegacyUserService) {
        self.legacy = legacy

        emptyCache = .init(
            [
                .userHashSnapshot: UserHashSnapshot.empty,
            ]
        )
        cache = emptyCache
    }

    // MARK: - User Creation

    public func createUser(
        id: String,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) async -> Callback<User, Exception> {
        let userHashesPath = "\(networking.config.paths.userHashes)/\(phoneNumber.nationalNumberString.digits.compressedHash)"
        var newValues = [id]

        let getValuesResult = await networking.database.getValues(at: userHashesPath)

        switch getValuesResult {
        case let .failure(exception):
            if !exception.isEqual(to: .noValueExists) {
                return .failure(exception)
            }

        case let .success(values):
            if let values = values as? [String] {
                newValues.append(contentsOf: values)
            }
        }

        if let exception = await networking.database.setValue(newValues.unique, forKey: userHashesPath) {
            return .failure(exception)
        }

        var resolvedPushTokens = Array.bangQualifiedEmpty
        if let pushTokens,
           !pushTokens.isBangQualifiedEmpty {
            resolvedPushTokens = pushTokens
        }

        typealias Keys = User.SerializationKeys
        let data: [String: Any] = [
            Keys.conversations.rawValue: Array.bangQualifiedEmpty,
            Keys.languageCode.rawValue: languageCode,
            Keys.phoneNumber.rawValue: phoneNumber.encoded,
            Keys.pushTokens.rawValue: resolvedPushTokens,
        ]

        if let exception = await networking.database.setValue(
            data,
            forKey: "\(networking.config.paths.users)/\(id)"
        ) {
            return .failure(exception)
        }

        return .success(.init(
            id,
            conversations: nil,
            languageCode: languageCode,
            phoneNumber: phoneNumber,
            pushTokens: resolvedPushTokens
        ))
    }

    // MARK: - Retrieval by Hash

    private func getUserHashes() async -> Callback<[String: [String]], Exception> {
        if let cachedValue = cache.value(forKey: .userHashSnapshot) as? UserHashSnapshot,
           !cachedValue.hashes.isEmpty,
           !Array(cachedValue.hashes.keys).contains(where: \.isBangQualifiedEmpty),
           !cachedValue.hashes.values.contains(where: \.isBangQualifiedEmpty),
           !cachedValue.isExpired {
            return .success(cachedValue.hashes)
        }

        let getValuesResult = await networking.database.getValues(at: networking.config.paths.userHashes)

        switch getValuesResult {
        case let .success(values):
            guard let hashes = values as? [String: [String]] else {
                return .failure(.init("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line]))
            }
            cache.set(
                UserHashSnapshot(
                    date: Date(),
                    hashes: hashes,
                    expiryThreshold: .seconds(60)
                ),
                forKey: .userHashSnapshot
            )
            return .success(hashes)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getUserIDs(hashes: [String]) async -> Callback<[String: [String]], Exception> {
        guard !hashes.isBangQualifiedEmpty else {
            return .failure(.init("No hashes provided.", metadata: [self, #file, #function, #line]))
        }

        let getUserHashesResult = await getUserHashes()

        switch getUserHashesResult {
        case let .success(userHashes):
            var matches = [String: [String]]()
            for hash in hashes {
                guard let userIDs = userHashes[hash] else { continue }
                matches[hash] = userIDs
            }

            guard !matches.isEmpty else {
                return .failure(.init(
                    "No user exists with the possible hashes.",
                    extraParams: ["PossibleHashes": hashes],
                    metadata: [self, #file, #function, #line]
                ))
            }

            return .success(matches)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Retrieval by ID

    public func getUser(id: String) async -> Callback<User, Exception> {
        let commonParams = ["UserID": id]

        guard !id.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let getValuesResult = await networking.database.getValues(at: "\(networking.config.paths.users)/\(id)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception = Exception("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            data["id"] = id
            return await User.decode(from: data)

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    public func getUsers(ids: [String]) async -> Callback<[User], Exception> {
        let commonParams = ["UserIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            return .failure(.init(
                "No IDs provided.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        var users = [User]()

        for id in ids {
            let getUserResult = await getUser(id: id)

            switch getUserResult {
            case let .success(user):
                users.append(user)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }
        }

        guard !users.isEmpty,
              users.count == ids.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(users)
    }

    // MARK: - Retrieval by Phone Number

    public func getUsers(phoneNumber: PhoneNumber) async -> Callback<[User], Exception> {
        var matches = [User]()

        guard let possibleHashes = phoneNumberService.possibleHashes(for: phoneNumber.compiledNumberString) else {
            return .failure(.init(
                "No possible hashes for this number.",
                extraParams: ["PhoneNumber": phoneNumber],
                metadata: [self, #file, #function, #line]
            ))
        }

        let getUserIDsResult = await getUserIDs(hashes: possibleHashes)

        switch getUserIDsResult {
        case let .success(userIDs):
            let identifiers = userIDs.values.reduce([], +)
            let getUsersResult = await getUsers(ids: identifiers)

            switch getUsersResult {
            case let .success(users):
                matches = users.filter { $0.phoneNumber.callingCode == phoneNumber.callingCode }
                guard !matches.isEmpty else {
                    @Persistent(.mismatchedHashes) var mismatchedHashes: [String]?
                    mismatchedHashes = mismatchedHashes == nil ? .init() : mismatchedHashes
                    mismatchedHashes?.append(contentsOf: possibleHashes)
                    mismatchedHashes = mismatchedHashes?.unique

                    return .failure(.init(
                        "There are matching hashes for this number, but no users have any of the possible calling codes.",
                        extraParams: ["PhoneNumber": phoneNumber],
                        metadata: [self, #file, #function, #line]
                    ))
                }

                return .success(matches)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    public func getUsers(phoneNumbers: [PhoneNumber]) async -> Callback<[NumberPair], Exception> {
        let commonParams = ["PhoneNumbers": phoneNumbers.map(\.encoded)]

        guard !phoneNumbers.isEmpty else {
            return .failure(.init("No phone numbers provided.", metadata: [self, #file, #function, #line]))
        }

        var matches = [NumberPair]()

        for number in phoneNumbers {
            let getUsersResult = await getUsers(phoneNumber: number)

            switch getUsersResult {
            case let .success(users):
                matches.append(.init(phoneNumber: number, users: users))

            case let .failure(exception):
                if !exception.isEqual(toAny: [.noUserWithHashes, .noValueExists]) {
                    return .failure(exception.appending(extraParams: commonParams))
                }
            }
        }

        guard !matches.isEmpty else {
            let exception = Exception(
                "No users with provided phone numbers.",
                metadata: [self, #file, #function, #line]
            )
            return .failure(exception.appending(extraParams: commonParams))
        }

        return .success(matches)
    }

    // MARK: - Get Users for Conversation

    public func getUsers(conversation: Conversation) async -> Callback<[User], Exception> {
        let commonParams = ["ConversationID": conversation.id.encoded]

        let userIDs = conversation.participants.map(\.userID).filter { $0 != userSessionService.currentUser?.id }
        guard !userIDs.isBangQualifiedEmpty else {
            let exception = Exception("No participants for this conversation.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let getUsersResult = await networking.services.user.getUsers(ids: userIDs)

        switch getUsersResult {
        case let .success(users):
            guard !users.isEmpty,
                  users.count == userIDs.count else {
                let exception = Exception("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            return .success(users)

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum UserServiceCacheDomainKey: String, Equatable {
        case userHashSnapshot
    }
}

private extension Cache {
    convenience init(_ objects: [CacheDomain.UserServiceCacheDomainKey: Any]) {
        var mappedObjects = [CacheDomain: Any]()
        objects.forEach { object in
            mappedObjects[.userService(object.key)] = object.value
        }
        self.init(mappedObjects)
    }

    func set(_ value: Any, forKey key: CacheDomain.UserServiceCacheDomainKey) {
        set(value, forKey: .userService(key))
    }

    func value(forKey key: CacheDomain.UserServiceCacheDomainKey) -> Any? {
        value(forKey: .userService(key))
    }
}
