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

    // MARK: - Update Push Tokens for Current User

    func updatePushTokensForCurrentUser() async -> Exception? {
        guard let currentUser = userSession.currentUser,
              let currentToken else {
            return .init("Either current user or push token has not been set.", metadata: .init(sender: self))
        }

        var pushTokens = currentUser.pushTokens ?? []
        guard !pushTokens.contains(currentToken) else {
            return .init(
                "Push tokens already up to date.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        pushTokens.append(currentToken)
        let updateValueResult = await currentUser.updateValue(pushTokens.unique, forKey: .pushTokens)

        switch updateValueResult {
        case let .success(user):
            return userSession.setCurrentUser(user)

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Prune Push Tokens for Current User

    func prunePushTokensForCurrentUser() async -> Exception? {
        guard let currentUser = userSession.currentUser,
              let currentUserPushTokens = currentUser.pushTokens else { return nil }

        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed("dictionary", metadata: .init(sender: self))
            }

            var tookAction = false
            for (key, value) in dictionary where key != currentUser.id {
                guard let userData = value as? [String: Any],
                      var pushTokens = userData[User.SerializationKeys.pushTokens.rawValue] as? [String],
                      !pushTokens.isBangQualifiedEmpty,
                      pushTokens.containsAnyString(in: currentUserPushTokens) else { continue }

                tookAction = true
                pushTokens = pushTokens.filter { !currentUserPushTokens.contains($0) }
                if let exception = await networking.database.setValue(
                    pushTokens.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : pushTokens,
                    forKey: "\(NetworkPath.users.rawValue)/\(key)/\(User.SerializationKeys.pushTokens.rawValue)"
                ) {
                    return exception
                }
            }

            guard tookAction else { return nil }
            Logger.log(
                "Pruned push tokens for current user.",
                sender: self
            )
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
