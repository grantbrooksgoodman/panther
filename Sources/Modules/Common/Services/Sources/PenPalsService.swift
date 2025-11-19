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

public struct PenPalsService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.networking.userService) private var userService: UserService
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Computed Properties

    private var contactPairArchiveUserIDs: [String] {
        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        return contactPairArchive?.map(\.users).reduce([], +).map(\.id).unique ?? []
    }

    private var selectContactPairUserIDs: [String] {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs) var selectedContactPairs: [ContactPair]?
        return selectedContactPairs?.users.map(\.id) ?? []
    }

    // MARK: - Init

    public init() {}

    // MARK: - Is Known to Current User

    public func isKnownToCurrentUser(_ userID: String) -> Bool {
        (contactPairArchiveUserIDs + currentUserConversationUserIDs()).contains(userID)
    }

    // MARK: - Is Obfuscated Pen Pal with Current User

    public func isObfuscatedPenPalWithCurrentUser(_ user: User) -> Bool {
        guard let currentUser = userSession.currentUser,
              let penPalsConversations = currentUser
              .conversations?
              .visibleForCurrentUser
              .filter(\.metadata.isPenPalsConversation) else { return false }
        return penPalsConversations.contains(where: { !$0.userSharesPenPalsDataWithCurrentUser(user) })
    }

    // MARK: - Update Sharing Data for Known Users

    /// - Note: Will populate the contact pair archive and the current user's conversations if either are `nil` or empty.
    public func updateSharingDataForKnownUsers() async -> Exception? {
        if let exception = await populateValuesIfNeeded() {
            Logger.log(exception, domain: .penPals)
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
                      .contains(where: { isKnownToCurrentUser($0) }) }) else { return nil }

        for penPalsConversation in penPalsConversationsWithKnownUsers {
            guard let currentUserPenPalsSharingData = penPalsConversation.currentUserPenPalsSharingData else { continue }
            let knownToCurrentUser = penPalsConversation
                .participants
                .map(\.userID)
                .filter { $0 != currentUser.id }
                .reduce(into: [String]()) { partialResult, userID in
                    if isKnownToCurrentUser(userID) { partialResult.append(userID) }
                }

            let newCurrentUserSharesDataWithUserIDs = ((currentUserPenPalsSharingData.sharesDataWithUserIDs ?? []) + knownToCurrentUser).unique
            var newPenPalsSharingData = penPalsConversation.metadata.penPalsSharingData.filter { $0.userID != currentUser.id }
            newPenPalsSharingData.append(
                .init(
                    userID: currentUser.id,
                    sharesDataWithUserIDs: newCurrentUserSharesDataWithUserIDs.isEmpty ? nil : newCurrentUserSharesDataWithUserIDs
                )
            )

            let newMetadata: ConversationMetadata = newPenPalsSharingData.allShareWithEachOther ? penPalsConversation.metadata.copyWith(
                isPenPalsConversation: false,
                penPalsSharingData: PenPalsSharingData.empty(userIDs: penPalsConversation.participants.map(\.userID)),
            ) : penPalsConversation.metadata.copyWith(
                penPalsSharingData: newPenPalsSharingData,
            )

            guard penPalsConversation.metadata != newMetadata else { continue }
            let updateValueResult = await penPalsConversation.updateValue(
                newMetadata,
                forKey: .metadata
            )

            switch updateValueResult {
            case .success: // NIT: We don't care about the result because updateValue adds the updated conversation to the archive for us.
                Logger.log(
                    .init(
                        "Updated PenPals sharing data.",
                        isReportable: false,
                        userInfo: ["ConversationIDKey": penPalsConversation.id.key],
                        metadata: .init(sender: self)
                    ),
                    domain: .penPals
                )

            case let .failure(exception):
                return exception
            }
        }

        return nil
    }

    // MARK: - Get Random PenPals Participant

    public func getRandomPenPalsParticipant() async -> Callback<User, Exception> {
        if let exception = await populateValuesIfNeeded() {
            Logger.log(exception, domain: .penPals)
        }

        let getAllUsersResult = await userService.getAllUsers() // TODO: Will need to be a limited query once user numbers pick up.

        switch getAllUsersResult {
        case let .success(users):
            guard let randomPenPalsParticipant = users
                .filter({ $0.isPenPalsParticipant })
                .filter({ $0.languageCode != userSession.currentUser?.languageCode })
                .filter({ !(userSession.currentUser?.blockedUserIDs?.contains($0.id) ?? false) })
                .filter({ !contactPairArchiveUserIDs.contains($0.id) })
                .filter({ !currentUserConversationUserIDs(excludePenPalsConversations: false).contains($0.id) })
                .filter({ !selectContactPairUserIDs.contains($0.id) })
                .randomElement() else {
                return .failure(.init(
                    "Failed to resolve random PenPals participant.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ))
            }

            return .success(randomPenPalsParticipant)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Set didGrantPenPalsPermission

    public func setDidGrantPenPalsPermission(_ didGrantPenPalsPermission: Bool) async -> Exception? {
        guard let currentUser = userSession.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        let updateValueResult = await currentUser.updateValue(
            didGrantPenPalsPermission,
            forKey: .isPenPalsParticipant
        )

        switch updateValueResult {
        case let .success(user):
            Observables.didGrantPenPalsPermission.value = didGrantPenPalsPermission
            return userSession.setCurrentUser(user)

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Auxiliary

    private func currentUserConversationUserIDs(excludePenPalsConversations: Bool = true) -> [String] {
        let visibleConversations = userSession.currentUser?.conversations?.visibleForCurrentUser

        guard excludePenPalsConversations else {
            return visibleConversations?
                .compactMap(\.users)
                .reduce([], +)
                .map(\.id)
                .unique ?? []
        }

        return visibleConversations?
            .filter { !$0.metadata.isPenPalsConversation }
            .compactMap(\.users)
            .reduce([], +)
            .map(\.id)
            .unique ?? []
    }

    private func populateValuesIfNeeded() async -> Exception? {
        @Dependency(\.commonServices.permission.contactPermissionStatus) var contactPermissionStatus: PermissionService.PermissionStatus
        var exceptions = [Exception]()

        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        if contactPairArchive == nil || contactPairArchive?.isEmpty == true,
           contactPermissionStatus == .granted,
           let exception = await contactService.syncContactPairArchive() {
            exceptions.append(exception)
        }

        guard let currentUser = userSession.currentUser,
              currentUser.conversations == nil || currentUser.conversations?.isEmpty == true else { return exceptions.compiledException }

        if let exception = await currentUser.setConversations() {
            exceptions.append(exception)
        }

        return exceptions.compiledException
    }
}
