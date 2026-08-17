//
//  PenPalsService.swift
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

/// Use ``PenPalsService`` to manage the PenPals feature.
///
/// PenPals pairs the user with participants who speak other languages. A participant's
/// identity remains obfuscated in a PenPals conversation until they share their data with the
/// other participants.
struct PenPalsService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.networking.userService) private var userService: UserService
    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService

    // MARK: - Properties

    @SharedState(\.didGrantPenPalsPermission) private var didGrantPenPalsPermission

    // MARK: - Computed Properties

    private var contactPairArchiveUserIDs: [String] {
        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        return contactPairArchive?.flatMap(\.userIDs).unique ?? []
    }

    @MainActor
    private var selectContactPairUserIDs: [String] {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        return chatPageViewService
            .recipientBar?
            .contactSelectionUI
            .selectedContactPairs
            .userIDs ?? []
    }

    // MARK: - Is Known to Current User

    /// Returns a Boolean value that indicates whether the given user ID belongs to a user
    /// known to the current user.
    ///
    /// A user is known if they appear in the contact pair archive or in one of the current
    /// user's visible non–PenPals conversations.
    ///
    /// - Parameter userID: The user ID to check.
    ///
    /// - Returns: `true` if the user is known to the current user; otherwise, `false`.
    func isKnownToCurrentUser(_ userID: String) -> Bool {
        (contactPairArchiveUserIDs + currentUserConversationUserIDs()).contains(userID)
    }

    // MARK: - Is Obfuscated Pen Pal with Current User

    /// Returns a Boolean value that indicates whether the given user is a PenPals participant
    /// who has not shared their data with the current user.
    ///
    /// - Parameter user: The user to check.
    ///
    /// - Returns: `true` if the user participates in one of the current user's visible Pen
    ///   Pals conversations without sharing their data; otherwise, `false`.
    func isObfuscatedPenPalWithCurrentUser(_ user: User) -> Bool {
        guard let currentUser = userSession.currentUser,
              let penPalsConversations = currentUser
              .conversations?
              .visibleForCurrentUser
              .filter(\.metadata.isPenPalsConversation) else { return false }
        return penPalsConversations.contains(where: { !$0.userSharesPenPalsDataWithCurrentUser(user) })
    }

    // MARK: - Update Sharing Data for Known Users

    /// Shares the current user's PenPals data with conversation participants they already
    /// know.
    ///
    /// For each visible PenPals conversation containing a participant known to the current
    /// user, this method updates the conversation's sharing data to include every known
    /// participant, unless all of them are already included.
    ///
    /// - Note: Populates the contact pair archive if it is `nil` or empty.
    ///
    /// - Throws: An `Exception` if updating a conversation's sharing data fails.
    func updateSharingDataForKnownUsers() async throws(Exception) {
        do {
            try await ContactService.syncIfNeeded()
        } catch {
            Logger.log(
                error,
                domain: .penPals
            )
        }

        guard let currentUser = userSession.currentUser,
              let penPalsConversationsWithKnownUsers = currentUser
              .conversations?
              .visibleForCurrentUser
              .filter({ $0
                      .metadata
                      .isPenPalsConversation && $0.participants
                      .map(\.userID)
                      .filter { $0 != currentUser.id }
                      .contains(where: { isKnownToCurrentUser($0) }) }) else { return }

        let conversationsAndKnownUserIDs: [(
            Conversation,
            [String]
        )] = penPalsConversationsWithKnownUsers
            .compactMap { penPalsConversation in
                guard let currentUserPenPalsSharingData = penPalsConversation.currentUserPenPalsSharingData else { return nil }
                let knownToCurrentUser = penPalsConversation
                    .participants
                    .map(\.userID)
                    .filter { $0 != currentUser.id }
                    .reduce(into: [String]()) { partialResult, userID in
                        if isKnownToCurrentUser(userID) { partialResult.append(userID) }
                    }

                let currentUserSharesDataWithUserIDs = currentUserPenPalsSharingData.sharesDataWithUserIDs ?? []
                guard !knownToCurrentUser.allSatisfy({
                    currentUserSharesDataWithUserIDs.contains($0)
                }) else { return nil }
                return (
                    penPalsConversation,
                    knownToCurrentUser
                )
            }

        try await conversationsAndKnownUserIDs.forEachConcurrently { conversation, knownUserIDs throws(Exception) in
            _ = try await conversation.updatePenPalsSharingData(
                sharingWith: knownUserIDs
            )

            Logger.log(
                .init(
                    "Updated PenPals sharing data.",
                    isReportable: false,
                    userInfo: ["ConversationIDKey": conversation.id.key],
                    metadata: .init(sender: self)
                ),
                domain: .penPals
            )
        }
    }

    // MARK: - Get Random PenPals Participant

    /// Returns a random PenPals participant suitable for pairing with the current user.
    ///
    /// Candidates must speak a language different from the current user's, and must not have
    /// blocked or been blocked by the current user, be known to the current user, be present in
    /// an existing conversation, or be currently selected as a recipient.
    ///
    /// - Note: Populates the contact pair archive if it is `nil` or empty.
    ///
    /// - Returns: A randomly chosen eligible participant.
    ///
    /// - Throws: An `Exception` if no eligible participant exists, or if fetching users fails.
    func getRandomPenPalsParticipant() async throws(Exception) -> User {
        do {
            try await ContactService.syncIfNeeded()
        } catch {
            Logger.log(
                error,
                domain: .penPals
            )
        }

        let selectContactPairUserIDs = await MainActor.run { self.selectContactPairUserIDs }
        // TODO: Will need to be a limited query once user numbers pick up.
        let users = try await userService.getAllUsers()

        guard let randomPenPalsParticipant = users
            .filter(\.isPenPalsParticipant)
            .filter({ $0.languageCode != userSession.currentUser?.languageCode })
            .filter({ !(userSession.currentUser?.blockedUserIDs?.contains($0.id) ?? false) })
            .filter({ candidate in
                guard let currentUserID = userSession.currentUser?.id else { return true }
                return !(candidate.blockedUserIDs ?? []).contains(currentUserID)
            })
            .filter({ !contactPairArchiveUserIDs.contains($0.id) })
            .filter({ !currentUserConversationUserIDs(excludePenPalsConversations: false).contains($0.id) })
            .filter({ !selectContactPairUserIDs.contains($0.id) })
            .randomElement() else {
            throw Exception(
                "Failed to resolve random PenPals participant.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        return randomPenPalsParticipant
    }

    // MARK: - Set didGrantPenPalsPermission

    /// Records whether the user granted permission to participate in PenPals.
    ///
    /// This method updates the shared permission state and persists the choice to the current
    /// user's remote record.
    ///
    /// - Parameter didGrantPenPalsPermission: A Boolean value that indicates whether the user
    ///   granted permission.
    ///
    /// - Throws: An `Exception` if the current user has not been set, or if the update fails.
    func setDidGrantPenPalsPermission(
        _ didGrantPenPalsPermission: Bool
    ) async throws(Exception) {
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        self.didGrantPenPalsPermission = didGrantPenPalsPermission
        _ = try await currentUser.update(
            \.isPenPalsParticipant,
            to: didGrantPenPalsPermission
        )
    }

    // MARK: - Auxiliary

    private func currentUserConversationUserIDs(excludePenPalsConversations: Bool = true) -> [String] {
        let visibleConversations = userSession.currentUser?.conversations?.visibleForCurrentUser

        guard excludePenPalsConversations else {
            return visibleConversations?
                .flatMap { $0.users ?? [] }
                .map(\.id)
                .unique ?? []
        }

        return visibleConversations?
            .filter { !$0.metadata.isPenPalsConversation }
            .flatMap { $0.users ?? [] }
            .map(\.id)
            .unique ?? []
    }
}
