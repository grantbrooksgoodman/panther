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

final class UserService: @unchecked Sendable {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case userDataSnapshots
    }

    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.phoneNumber) private var phoneNumberService: PhoneNumberService

    // MARK: - Properties

    let testing: UserTestingService

    @Cached(CacheKey.userDataSnapshots) private var cachedUserDataSnapshots: [UserDataSnapshot]?

    // MARK: - Init

    init(testing: UserTestingService) {
        self.testing = testing
    }

    // MARK: - User Creation

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
            isPenPalsParticipant: false,
            languageCode: languageCode,
            lastSignedIn: nil,
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

    func getAllUsers() async throws(Exception) -> [User] {
        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        return try await getUsers(
            ids: Array(userData.keys)
        )
    }

    // MARK: - Retrieval by ID

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
                return try await User(from: match.data)
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
            return try await User(from: data)
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

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
            return try await ids.map(
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

    func clearCache() {
        cachedUserDataSnapshots = nil
    }
}
