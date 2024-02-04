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

// swiftlint:disable:next type_body_length
public final class UserService: Cacheable {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

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
                .userDataSnapshots: [],
                .userNumberHashSnapshot: UserNumberHashSnapshot.empty,
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
        let getUserIDsResult = await getUserIDs(phoneNumber: phoneNumber)

        switch getUserIDsResult {
        case .success:
            return .failure(.init(
                "User already exists for this phone number.",
                extraParams: ["PhoneNumber": phoneNumber.encoded],
                metadata: [self, #file, #function, #line]
            ))

        default: ()
        }

        let userNumberHashesPath = "\(networking.config.paths.userNumberHashes)/\(phoneNumber.nationalNumberString.digits.encodedHash)"
        var newValues = [id]

        let getValuesResult = await networking.database.getValues(at: userNumberHashesPath)

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

        if let exception = await networking.database.setValue(newValues.unique, forKey: userNumberHashesPath) {
            return .failure(exception)
        }

        let mockUser: User = .init(
            id,
            badgeNumber: 0,
            conversationIDs: nil,
            languageCode: languageCode,
            phoneNumber: phoneNumber,
            pushTokens: pushTokens
        )

        let data = mockUser.encoded.filter { $0.key != User.SerializationKeys.id.rawValue }

        if let exception = await networking.database.setValue(
            data,
            forKey: "\(networking.config.paths.users)/\(id)"
        ) {
            return .failure(exception)
        }

        return .success(mockUser)
    }

    // MARK: - Retrieval by Hash

    private func getUserNumberHashes() async -> Callback<[String: [String]], Exception> {
        if let cachedValue = cache.value(forKey: .userNumberHashSnapshot) as? UserNumberHashSnapshot,
           !cachedValue.hashes.isEmpty,
           !Array(cachedValue.hashes.keys).contains(where: \.isBangQualifiedEmpty),
           !cachedValue.hashes.values.contains(where: \.isBangQualifiedEmpty),
           !cachedValue.isExpired {
            Logger.log(
                "Returning cached user number hash snapshot.",
                domain: .user,
                metadata: [self, #file, #function, #line]
            )
            return .success(cachedValue.hashes)
        }

        let getValuesResult = await networking.database.getValues(at: networking.config.paths.userNumberHashes)

        switch getValuesResult {
        case let .success(values):
            guard let hashes = values as? [String: [String]] else {
                return .failure(.init("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line]))
            }
            cache.set(
                UserNumberHashSnapshot(
                    date: Date(),
                    hashes: hashes,
                    expiryThreshold: .seconds(60)
                ),
                forKey: .userNumberHashSnapshot
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

        let getUserNumberHashesResult = await getUserNumberHashes()

        switch getUserNumberHashesResult {
        case let .success(userNumberHashes):
            var matches = [String: [String]]()
            for hash in hashes {
                guard let userIDs = userNumberHashes[hash] else { continue }
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

        typealias Keys = User.SerializationKeys

        if let cachedValue = cache.value(forKey: .userDataSnapshots) as? [UserDataSnapshot],
           let match = cachedValue.first(where: { ($0.data[Keys.id.rawValue] as? String) == id }),
           !match.isExpired {
            Logger.log(
                .init(
                    "Returning cached user data snapshot.",
                    extraParams: ["UserID": id],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .user
            )
            return await User.decode(from: match.data)
        }

        let getValuesResult = await networking.database.getValues(at: "\(networking.config.paths.users)/\(id)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception = Exception("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            data[Keys.id.rawValue] = id

            @Persistent(.currentUserID) var currentUserID: String?; #warning("Not a fan of having this here.")
            if let languageCode = data[Keys.languageCode.rawValue] as? String,
               id == currentUserID {
                RuntimeStorage.store(languageCode, as: .languageCode)
            }

            var cacheValues = (cache.value(forKey: .userDataSnapshots) as? [UserDataSnapshot]) ?? []
            cacheValues.append(
                .init(
                    date: Date(),
                    data: data,
                    expiryThreshold: .milliseconds(100)
                )
            )
            cache.set(cacheValues, forKey: .userDataSnapshots)
            return await User.decode(from: data)

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    public func getUsers(ids: [String]) async -> Callback<[User], Exception> {
        let commonParams = ["UserIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            return .failure(.init(
                "No ID keys provided.",
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

    public func getUserIDs(phoneNumber: PhoneNumber) async -> Callback<[String], Exception> {
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
            return .success(userIDs.values.reduce([], +))

        case let .failure(exception):
            return .failure(exception)
        }
    }

    public func getUsers(phoneNumber: PhoneNumber) async -> Callback<[User], Exception> {
        var matches = [User]()

        let getUserIDsResult = await getUserIDs(phoneNumber: phoneNumber)

        switch getUserIDsResult {
        case let .success(userIDs):
            let getUsersResult = await getUsers(ids: userIDs)

            switch getUsersResult {
            case let .success(users):
                matches = users.filter { $0.phoneNumber.callingCode == phoneNumber.callingCode }
                guard !matches.isEmpty else {
                    guard let possibleHashes = phoneNumberService.possibleHashes(for: phoneNumber.compiledNumberString) else {
                        return .failure(.init(metadata: [self, #file, #function, #line]))
                    }

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

    // MARK: - Clear Cache

    public func clearCache() {
        CacheDomain.UserServiceCacheDomainKey.allCases.forEach { cache.removeObject(forKey: .userService($0)) }
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum UserServiceCacheDomainKey: String, CaseIterable, Equatable {
        case userDataSnapshots
        case userNumberHashSnapshot
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
