//
//  UserService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public final class UserService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case userDataSnapshots
    }

    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    public let legacy: LegacyUserService
    public let testing: UserTestingService

    @Cached(CacheKey.userDataSnapshots) private var cachedUserDataSnapshots: [UserDataSnapshot]?

    // MARK: - Init

    public init(
        legacy: LegacyUserService,
        testing: UserTestingService
    ) {
        self.legacy = legacy
        self.testing = testing
    }

    // MARK: - User Creation

    public func createUser(
        id: String,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) async -> Callback<User, Exception> {
        if await accountExists(for: phoneNumber) {
            return .failure(.init(
                "User already exists for this phone number.",
                userInfo: ["PhoneNumber": phoneNumber.encoded],
                metadata: .init(sender: self)
            ))
        }

        let mockUser: User = .init(
            id,
            blockedUserIDs: nil,
            conversationIDs: nil,
            isPenPalsParticipant: false,
            languageCode: languageCode,
            messageRecipientConsentRequired: false,
            phoneNumber: phoneNumber,
            previousLanguageCodes: nil,
            pushTokens: pushTokens
        )

        var data = mockUser.encoded.filter { $0.key != User.SerializationKeys.id.rawValue }
        data[User.SerializationKeys.badgeNumber.rawValue] = 0

        if let exception = await networking.database.setValue(
            data,
            forKey: "\(NetworkPath.users.rawValue)/\(id)"
        ) {
            return .failure(exception)
        }

        return .success(mockUser)
    }

    // MARK: - Collision Detection

    public func accountExists(for phoneNumber: PhoneNumber) async -> Bool {
        let getUserResult = await getUser(phoneNumber: phoneNumber)

        switch getUserResult {
        case .success: return true
        case .failure: return false
        }
    }

    // MARK: - Get All Users

    public func getAllUsers() async -> Callback<[User], Exception> {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.Networking.typecastFailed("dictionary", metadata: .init(sender: self)))
            }

            return await getUsers(ids: Array(dictionary.keys))

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Retrieval by ID

    public func getUser(id: String) async -> Callback<User, Exception> {
        let commonParams = ["UserID": id]

        guard !id.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: .init(sender: self))
            return .failure(exception.appending(userInfo: commonParams))
        }

        typealias Keys = User.SerializationKeys

        if let cachedUserDataSnapshots,
           let match = cachedUserDataSnapshots.first(where: { ($0.data[Keys.id.rawValue] as? String) == id }),
           !match.isExpired {
            Logger.log(
                .init(
                    "Returning cached user data snapshot.",
                    isReportable: false,
                    userInfo: ["UserID": id],
                    metadata: .init(sender: self)
                ),
                domain: .caches
            )
            return await User.decode(from: match.data)
        }

        let getValuesResult = await networking.database.getValues(at: "\(NetworkPath.users.rawValue)/\(id)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception: Exception = .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
                return .failure(exception.appending(userInfo: commonParams))
            }

            data[Keys.id.rawValue] = id

            var cachedValues = cachedUserDataSnapshots ?? []
            cachedValues.append(
                .init(
                    data: data,
                    expiryThreshold: .milliseconds(100)
                )
            )
            cachedUserDataSnapshots = cachedValues
            return await User.decode(from: data)

        case let .failure(exception):
            return .failure(exception.appending(userInfo: commonParams))
        }
    }

    public func getUsers(ids: [String]) async -> Callback<[User], Exception> {
        let commonParams = ["UserIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            return .failure(.init(
                "No ID keys provided.",
                metadata: .init(sender: self)
            ).appending(userInfo: commonParams))
        }

        var users = [User]()

        for id in ids {
            let getUserResult = await getUser(id: id)

            switch getUserResult {
            case let .success(user):
                users.append(user)

            case let .failure(exception):
                return .failure(exception.appending(userInfo: commonParams))
            }
        }

        guard !users.isEmpty,
              users.count == ids.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ).appending(userInfo: commonParams))
        }

        return .success(users)
    }

    // MARK: - Retrieval by Phone Number

    public func getUser(phoneNumber: PhoneNumber) async -> Callback<User, Exception> {
        let commonParams = ["PhoneNumber": phoneNumber.encoded]
        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                ).appending(userInfo: commonParams))
            }

            let getUsersResult = await networking.userService.getUsers(ids: Array(dictionary.keys))

            switch getUsersResult {
            case let .success(users):
                guard let user = users.first(where: { $0.phoneNumber.compiledNumberString == phoneNumber.compiledNumberString }) else {
                    return .failure(.init(
                        "No users with the provided phone number.",
                        isReportable: false,
                        metadata: .init(sender: self)
                    ).appending(userInfo: commonParams))
                }

                return .success(user)

            case let .failure(exception):
                return .failure(exception.appending(userInfo: commonParams))
            }

        case let .failure(exception):
            return .failure(exception.appending(userInfo: commonParams))
        }
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cachedUserDataSnapshots = nil
    }
}
