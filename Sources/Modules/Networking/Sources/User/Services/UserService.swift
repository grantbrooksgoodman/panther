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

/// The service that creates and retrieves users.
///
/// ``UserService`` creates new user records, fetches users by identifier or phone number, and
/// caches recently-fetched user data in short-lived snapshots. Every user it returns is upserted
/// into the session store.
final class UserService: @unchecked Sendable {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case userDataSnapshots
    }

    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore

    // MARK: - Properties

    /// The service that generates random user data for testing during development.
    let testing: UserTestingService

    @Cached(CacheKey.userDataSnapshots) private var cachedUserDataSnapshots: [UserDataSnapshot]?

    // MARK: - Init

    /// Creates a user service with the given testing service.
    ///
    /// - Parameter testing: The service that generates random user data for testing during
    ///   development.
    init(testing: UserTestingService) {
        self.testing = testing
    }

    // MARK: - User Creation

    /// Creates a new user with the given properties and writes it to the database.
    ///
    /// - Parameters:
    ///   - id: The identifier for the new user.
    ///   - languageCode: The user's language code.
    ///   - phoneNumber: The user's phone number.
    ///   - pushTokens: The user's push notification tokens, or `nil` if none.
    ///
    /// - Returns: The created user.
    ///
    /// - Throws: An `Exception` if an account already exists for the phone number, or if writing
    ///   the user fails.
    func createUser(
        id: String,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) async throws(Exception) -> User {
        if await accountExists(for: phoneNumber) {
            throw Exception(
                "User already exists for this phone number.",
                userInfo: ["PhoneNumber": phoneNumber.encoded],
                metadata: .init(sender: self)
            )
        }

        let mockUser: User = .init(
            id,
            aiEnhancedTranslationsEnabled: false,
            blockedUserIDs: nil,
            conversationIDs: nil,
            deviceID: DeviceID.current,
            isPenPalsParticipant: false,
            languageCode: languageCode,
            messageRecipientConsentRequired: false,
            phoneNumber: phoneNumber,
            previousLanguageCodes: nil,
            pushTokens: pushTokens
        )

        var data = mockUser.encoded.filter { $0.key != User.SerializableKey.id.rawValue }
        data[User.SerializableKey.badgeNumber.rawValue] = 0

        try await networking.database.setValue(
            data,
            forKey: "\(NetworkPath.users.rawValue)/\(id)"
        )

        return mockUser
    }

    // MARK: - Collision Detection

    /// Returns a Boolean value that indicates whether an account is registered with the given
    /// phone number.
    ///
    /// - Parameter phoneNumber: The phone number to check.
    ///
    /// - Returns: `true` if an account exists for the phone number; otherwise, `false`.
    func accountExists(
        for phoneNumber: PhoneNumber
    ) async -> Bool {
        do {
            _ = try await getUser(phoneNumber: phoneNumber)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Get All Users

    /// Returns every user in the database.
    ///
    /// - Returns: Every user.
    ///
    /// - Throws: An `Exception` if the users cannot be fetched.
    func getAllUsers() async throws(Exception) -> [User] {
        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        return try await getUsers(
            ids: Array(userData.keys)
        )
    }

    // MARK: - Retrieval by ID

    /// Returns the user with the given identifier.
    ///
    /// Unless bypassed, an unexpired cached snapshot is returned instead of re-fetching.
    ///
    /// - Parameters:
    ///   - id: The identifier of the user to fetch.
    ///   - bypassSnapshotCache: A Boolean value that determines whether to ignore the snapshot
    ///     cache and always fetch.
    ///   - cacheStrategy: The database cache strategy to apply for the fetch, or `nil` to use the
    ///     default.
    ///
    /// - Returns: The user.
    ///
    /// - Throws: An `Exception` if no identifier is provided or the user cannot be fetched or
    ///   decoded.
    func getUser(
        id: String,
        bypassSnapshotCache: Bool = false,
        cacheStrategy: CacheStrategy? = nil
    ) async throws(Exception) -> User {
        let userInfo = ["UserID": id]

        guard !id.isBangQualifiedEmpty else {
            throw Exception(
                "No ID provided.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        typealias Keys = User.SerializableKey

        if !bypassSnapshotCache,
           let cachedUserDataSnapshots,
           let match = cachedUserDataSnapshots.first(where: {
               ($0.data[Keys.id.rawValue] as? String) == id
           }),
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

            do {
                return try await user(from: match.data)
            } catch {
                throw error.appending(userInfo: userInfo)
            }
        }

        var data: [String: Any]
        do {
            if let cacheStrategy {
                networking.database.setGlobalCacheStrategy(cacheStrategy)
            }

            defer {
                if cacheStrategy != nil {
                    networking.database.setGlobalCacheStrategy(nil)
                }
            }

            data = try await networking.database.getValues(
                at: "\(NetworkPath.users.rawValue)/\(id)"
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        data[Keys.id.rawValue] = id

        var cachedValues = cachedUserDataSnapshots ?? []
        cachedValues.append(
            .init(
                data: data,
                expiryThreshold: .milliseconds(500)
            )
        )

        cachedUserDataSnapshots = cachedValues

        do {
            return try await user(from: data)
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

    /// Returns the users with the given identifiers, fetched concurrently.
    ///
    /// - Parameters:
    ///   - ids: The identifiers of the users to fetch.
    ///   - bypassSnapshotCache: A Boolean value that determines whether to ignore the snapshot
    ///     cache and always fetch.
    ///   - cacheStrategy: The database cache strategy to apply for the fetches, or `nil` to use
    ///     the default.
    ///
    /// - Returns: The users.
    ///
    /// - Throws: An `Exception` if no identifiers are provided or any user cannot be fetched.
    func getUsers(
        ids: [String],
        bypassSnapshotCache: Bool = false,
        cacheStrategy: CacheStrategy? = nil
    ) async throws(Exception) -> [User] {
        let userInfo = ["UserIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            throw Exception(
                "No ID keys provided.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        do {
            return try await ids.parallelMap(
                failForEmptyCollection: true
            ) {
                try await self.getUser(
                    id: $0,
                    bypassSnapshotCache: bypassSnapshotCache,
                    cacheStrategy: cacheStrategy
                )
            }
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

    // MARK: - Retrieval by Phone Number

    /// Returns the user registered with the given phone number.
    ///
    /// - Parameter phoneNumber: The phone number to match.
    ///
    /// - Returns: The matching user.
    ///
    /// - Throws: An `Exception` if no user is registered with the phone number, or if the users
    ///   cannot be fetched.
    func getUser(
        phoneNumber: PhoneNumber
    ) async throws(Exception) -> User {
        let userInfo = ["PhoneNumber": phoneNumber.encoded]

        let users: [User]
        do {
            users = try await getAllUsers()
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        guard let user = users.first(where: {
            $0.phoneNumber.compiledNumberString == phoneNumber.compiledNumberString
        }) else {
            throw Exception(
                "No users with the provided phone number.",
                isReportable: false,
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        return user
    }

    // MARK: - Clear Cache

    /// Removes every cached user data snapshot.
    func clearCache() {
        cachedUserDataSnapshots = nil
    }

    // MARK: - Auxiliary

    private func user(
        from data: [String: Any]
    ) async throws(Exception) -> User {
        let user = try await User(from: data)

        /* Single source of upsert for fetched users – guarantees any user
         this service returns is resolvable from the session store
         (e.g. NumberPair.users). Bypasses RemotelyUpdatable.update.
         */
        sessionStore.upsertUser(user)
        return user
    }
}
