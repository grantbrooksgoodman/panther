//
//  ChatGPTService+Account.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension ChatGPTService {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.ChatGPTService

    // MARK: - Resolve User

    /// Returns ChatGPT's user account, creating it if it does not
    /// exist.
    ///
    /// The account is upserted into the session store.
    ///
    /// - Returns: ChatGPT's user account.
    ///
    /// - Throws: An `Exception` if the account cannot be fetched or
    ///   created.
    func resolveUser() async throws(Exception) -> User {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        @Dependency(\.networking.userService) var userService: UserService

        if let user = sessionStore.users[CommonConstants.chatGPTUserID] {
            return user
        }

        do {
            return try await userService.getUser(
                id: CommonConstants.chatGPTUserID
            )
        } catch {
            guard error.isEqual(
                to: .Networking.Database.noValueExists
            ) else { throw error }
        }

        let user = try await userService.createUser(
            id: CommonConstants.chatGPTUserID,
            languageCode: Strings.languageCode,
            phoneNumber: .init(
                callingCode: Strings.phoneNumberCallingCode,
                nationalNumberString: Strings.phoneNumberNationalNumber,
                regionCode: Strings.phoneNumberRegionCode,
                label: nil,
                internalFormattedString: nil
            ),
            pushTokens: nil
        )

        sessionStore.upsertUser(user)
        return user
    }
}
