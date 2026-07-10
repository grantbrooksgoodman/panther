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

        let userIDsAndPrunedTokens: [(
            userID: String,
            prunedTokens: [String]
        )] = userData
            .compactMap { key, value in
                guard let userData = value as? [String: Any],
                      let pushTokens = userData[User.SerializableKey.pushTokens.rawValue] as? [String],
                      !pushTokens.isBangQualifiedEmpty,
                      pushTokens.contains(pushToken) else { return nil }
                let prunedTokens = pushTokens.filter { $0 != pushToken }
                return (
                    key,
                    prunedTokens.isBangQualifiedEmpty ? .bangQualifiedEmpty : prunedTokens
                )
            }

        guard !userIDsAndPrunedTokens.isEmpty else { return }
        try await userIDsAndPrunedTokens.map {
            try await self.networking.database.setValue(
                $0.prunedTokens,
                forKey: [
                    NetworkPath.users.rawValue,
                    $0.userID,
                    User.SerializableKey.pushTokens.rawValue,
                ].joined(separator: "/")
            )
        }

        Logger.log(
            "Erased stale push token for \(userIDsAndPrunedTokens.count) users.",
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
        try await userSession.setCurrentUser(
            currentUser.update(
                \.pushTokens,
                to: pushTokens.unique
            )
        )
    }

    // MARK: - Prune Push Tokens for Current User

    func prunePushTokensForCurrentUser() async throws(Exception) {
        guard let currentUser = userSession.currentUser,
              let currentUserPushTokens = currentUser.pushTokens else { return }

        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        let userIDsAndPrunedTokens: [(
            userID: String,
            prunedTokens: [String]
        )] = userData
            .filter { $0.key != currentUser.id }
            .compactMap { key, value in
                guard let userData = value as? [String: Any],
                      let pushTokens = userData[User.SerializableKey.pushTokens.rawValue] as? [String],
                      !pushTokens.isBangQualifiedEmpty,
                      pushTokens.containsAnyString(in: currentUserPushTokens) else { return nil }
                let prunedTokens = pushTokens.filter { !currentUserPushTokens.contains($0) }
                return (
                    key,
                    prunedTokens.isBangQualifiedEmpty ? .bangQualifiedEmpty : prunedTokens
                )
            }

        guard !userIDsAndPrunedTokens.isEmpty else { return }
        try await userIDsAndPrunedTokens.map {
            try await self.networking.database.setValue(
                $0.prunedTokens,
                forKey: [
                    NetworkPath.users.rawValue,
                    $0.userID,
                    User.SerializableKey.pushTokens.rawValue,
                ].joined(separator: "/")
            )
        }

        Logger.log(
            "Pruned push tokens for current user.",
            sender: self
        )
    }
}
