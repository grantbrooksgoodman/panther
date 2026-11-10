//
//  StagedUserService.swift
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

/// The service that resolves accounts for staged participant identities during development.
struct StagedUserService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Computed Properties

    /// The shared staged user service.
    static let shared = StagedUserService()

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    /// Resolves the account for the given staged identity, creating it if necessary.
    ///
    /// Staged accounts are identified by phone number. If no account holds the identity's number,
    /// one is created under the staged ID. If the current user holds the number, they stand in for
    /// the identity and are returned untouched, so screenshots can be captured while signed in as
    /// a staged persona. If any other account holds the number under a different ID, that account
    /// is retired – removed from its conversations, listed as deleted, and erased – and recreated
    /// under the staged ID, so the number is never shared by two accounts.
    ///
    /// Resolved accounts other than the current user leave their device unclaimed rather than
    /// claiming the current device.
    ///
    /// - Parameter identity: The staged identity to resolve.
    ///
    /// - Returns: The account for the identity.
    ///
    /// - Throws: An `Exception` if the account cannot be resolved.
    @MainActor
    func resolveUser(
        for identity: StagedUserIdentity
    ) async throws(Exception) -> User {
        if await networking.userService.accountExists(
            for: identity.phoneNumber
        ) {
            let existingUser = try await networking.userService.getUser(
                phoneNumber: identity.phoneNumber
            )

            guard existingUser.id != User.currentUserID else { return existingUser }
            guard existingUser.id != identity.id else {
                return try await unclaimDevice(for: existingUser)
            }

            try await retire(existingUser)
        }

        let user = try await networking.userService.createUser(
            id: identity.id,
            languageCode: identity.languageCode,
            phoneNumber: identity.phoneNumber,
            pushTokens: nil
        )

        return try await unclaimDevice(for: user)
    }

    // MARK: - Auxiliary

    private func addToDeletedUsers(
        _ userID: String
    ) async throws(Exception) {
        try await networking.database.runTransaction(
            at: NetworkPath.deletedUsers.rawValue
        ) { currentValue in
            var ids = (currentValue as? [String]) ?? []
            ids.append(userID)
            return ids.filter { $0 != String.bangQualifiedEmpty }.unique
        }
    }

    @MainActor
    private func retire(
        _ user: User
    ) async throws(Exception) {
        // Mirror account deletion: leave group chats, delete
        // one-to-one chats, then erase the record and let the
        // integrity sweep reconcile lingering references.
        if let idKeys = user.conversationIDs?.map(\.key),
           !idKeys.isEmpty {
            let conversations = try await networking.conversationService.getConversations(
                idKeys: idKeys
            )

            for conversation in conversations {
                if conversation.participants.count > 2 {
                    try await entitySession.activity.removeFromConversation(
                        user.id,
                        conversation: conversation,
                        removeFromUser: false
                    )
                } else {
                    try await entitySession.conversation.deleteConversation(
                        conversation,
                        forced: true
                    )
                }
            }
        }

        try await addToDeletedUsers(user.id)
        try await networking.database.setValue(
            NSNull(),
            forKey: "\(NetworkPath.users.rawValue)/\(user.id)"
        )

        networking.userService.clearCache()
        try await networking.integrityService.repairDatabase()
    }

    private func unclaimDevice(
        for user: User
    ) async throws(Exception) -> User {
        guard user.deviceID != .bangQualifiedEmpty else { return user }
        return try await user.update(
            \.deviceID,
            to: .bangQualifiedEmpty
        )
    }
}
