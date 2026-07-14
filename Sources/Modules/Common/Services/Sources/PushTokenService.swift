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

final class PushTokenService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    private(set) var currentToken: String?

    // MARK: - Set Push Token

    func setCurrentToken(_ currentToken: String?) {
        self.currentToken = currentToken
    }

    // MARK: - Erase Stale Push Token

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
            guard let userData = value as? [String: Any] else { continue }
            let rawPushTokens = userData[User.SerializableKey.pushTokens.rawValue]
            let basePath = [
                NetworkPath.users.rawValue,
                userID,
                User.SerializableKey.pushTokens.rawValue,
            ].joined(separator: "/")

            if let map = rawPushTokens as? [String: Any],
               map[pushToken] != nil {
                updates["\(basePath)/\(pushToken)"] = NSNull()
            } else if let array = rawPushTokens as? [String],
                      !array.isBangQualifiedEmpty,
                      array.contains(pushToken) {
                // Legacy array: rewrite as map minus stale token.
                var newMap = [String: Bool]()
                for token in array where token != pushToken {
                    newMap[token] = true
                }

                updates[basePath] = newMap.isEmpty ? [String: Bool]() : newMap
            }
        }

        guard !updates.isEmpty else { return }
        try await networking.database.commit(updates)

        Logger.log(
            "Erased stale push token for \(updates.count) users.",
            sender: self
        )
    }

    // MARK: - Update Push Tokens for Current User

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

    func prunePushTokensForCurrentUser() async throws(Exception) {
        guard let currentUser = userSession.currentUser,
              let currentUserPushTokens = currentUser.pushTokens else { return }

        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        // Build a single fan-out that removes the current
        // user's tokens from all other users.
        let currentTokenSet = Set(currentUserPushTokens)
        var updates = [String: Any]()
        for (userID, value) in userData where userID != currentUser.id {
            guard let userData = value as? [String: Any] else { continue }
            let rawPushTokens = userData[User.SerializableKey.pushTokens.rawValue]
            let basePath = [
                NetworkPath.users.rawValue,
                userID,
                User.SerializableKey.pushTokens.rawValue,
            ].joined(separator: "/")

            if let map = rawPushTokens as? [String: Any] {
                for token in map.keys where currentTokenSet.contains(token) {
                    updates["\(basePath)/\(token)"] = NSNull()
                }
            } else if let array = rawPushTokens as? [String],
                      !array.isBangQualifiedEmpty,
                      array.containsAnyString(in: currentUserPushTokens) {
                // Legacy array: rewrite as map minus current
                // user's tokens.
                var newMap = [String: Bool]()
                for token in array where !currentTokenSet.contains(token) {
                    newMap[token] = true
                }

                updates[basePath] = newMap.isEmpty ? [String: Bool]() : newMap
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
