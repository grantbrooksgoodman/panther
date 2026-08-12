//
//  PushTokenService.swift
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

/// Use ``PushTokenService`` to manage the device push notification tokens registered for
/// users.
///
/// Each user's remote record holds the push tokens of the devices on which they are signed in.
final class PushTokenService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService

    // MARK: - Properties

    /// The device's current push token, or `nil` if one has not been set.
    private(set) var currentToken: String?

    // MARK: - Set Push Token

    /// Sets the device's current push token.
    ///
    /// - Parameter currentToken: The token to set; pass `nil` to clear it.
    func setCurrentToken(_ currentToken: String?) {
        self.currentToken = currentToken
    }

    // MARK: - Erase Stale Push Token

    /// Removes the given push token from every user that holds it.
    ///
    /// All removals are committed as a single batched update. If no user holds the token, this
    /// method returns immediately.
    ///
    /// - Parameter pushToken: The stale token to remove.
    ///
    /// - Throws: An `Exception` if fetching user data or committing the update fails.
    func eraseStalePushToken(
        _ pushToken: String
    ) async throws(Exception) {
        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        // Build a single fan-out that deletes the stale
        // token from every user that has it.
        var updates = [String: Any]()
        for (userID, value) in userData {
            guard let userData = value as? [String: Any],
                  let pushTokenMap = userData[
                      User.SerializableKey.pushTokens.rawValue
                  ] as? [String: Any],
                  pushTokenMap[pushToken] != nil else { continue }

            let basePath = [
                NetworkPath.users.rawValue,
                userID,
                User.SerializableKey.pushTokens.rawValue,
            ].joined(separator: "/")

            updates[
                [
                    basePath,
                    pushToken,
                ].joined(separator: "/")
            ] = NSNull()
        }

        guard !updates.isEmpty else { return }
        try await networking.database.commit(updates)

        Logger.log(
            "Erased stale push token for \(updates.count) users.",
            sender: self
        )
    }

    // MARK: - Update Push Tokens for Current User

    /// Adds the device's current push token to the current user's remote record.
    ///
    /// - Throws: An `Exception` if the current user or token has not been set, if the token is
    ///   already registered, or if the update fails.
    func updatePushTokensForCurrentUser() async throws(Exception) {
        guard let currentUser = userSession.currentUser,
              let currentToken else {
            throw Exception(
                "Either current user or push token has not been set.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        var pushTokens = currentUser.pushTokens ?? []
        guard !pushTokens.contains(currentToken) else {
            throw Exception(
                "Push tokens already up to date.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        pushTokens.append(currentToken)
        _ = try await currentUser.update(
            \.pushTokens,
            to: pushTokens.unique
        )
    }

    // MARK: - Prune Push Tokens for Current User

    /// Removes the current user's push tokens from every other user's remote record.
    ///
    /// All removals are committed as a single batched update. If the current user has no push
    /// tokens, this method returns immediately.
    ///
    /// - Throws: An `Exception` if fetching user data or committing the update fails.
    func prunePushTokensForCurrentUser() async throws(Exception) {
        guard let currentUser = userSession.currentUser,
              let currentUserPushTokens = currentUser.pushTokens else { return }

        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        // Build a single fan-out that removes the current
        // user's tokens from all other users.
        var updates = [String: Any]()
        for (userID, value) in userData where userID != currentUser.id {
            guard let userData = value as? [String: Any],
                  let pushTokenMap = userData[
                      User.SerializableKey.pushTokens.rawValue
                  ] as? [String: Any] else { continue }

            let basePath = [
                NetworkPath.users.rawValue,
                userID,
                User.SerializableKey.pushTokens.rawValue,
            ].joined(separator: "/")

            for token in pushTokenMap.keys where Set(currentUserPushTokens).contains(token) {
                updates[
                    [
                        basePath,
                        token,
                    ].joined(separator: "/")
                ] = NSNull()
            }
        }

        guard !updates.isEmpty else { return }
        try await networking.database.commit(updates)

        Logger.log(
            "Pruned push tokens for current user.",
            sender: self
        )
    }
}
