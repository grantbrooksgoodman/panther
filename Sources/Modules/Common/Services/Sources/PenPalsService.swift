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

    func isKnownToCurrentUser(_ userID: String) -> Bool {
        (contactPairArchiveUserIDs + currentUserConversationUserIDs()).contains(userID)
    }

    // MARK: - Is Obfuscated Pen Pal with Current User

    func isObfuscatedPenPalWithCurrentUser(_ user: User) -> Bool {
        guard let currentUser = userSession.currentUser,
              let penPalsConversations = currentUser
              .conversations?
              .visibleForCurrentUser
              .filter(\.metadata.isPenPalsConversation) else { return false }
        return penPalsConversations.contains(where: { !$0.userSharesPenPalsDataWithCurrentUser(user) })
    }

    // MARK: - Update Sharing Data for Known Users

    /// - Note: Will populate the contact pair archive if it is `nil` or empty.
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
