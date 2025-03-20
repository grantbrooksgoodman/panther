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

public final class PenPalsService {
    // MARK: - Dependencies

    @Dependency(\.networking.userService) private var userService: UserService
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    public private(set) var didGrantPenPalsPermission = false

    // MARK: - Computed Properties

    private var contactPairArchiveUserIDs: [String] {
        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        return contactPairArchive?.map(\.users).reduce([], +).map(\.id).unique ?? []
    }

    private var currentUserConversationUserIDs: [String] {
        userSession
            .currentUser?
            .conversations?
            .visibleForCurrentUser
            .compactMap(\.users)
            .reduce([], +)
            .map(\.id)
            .unique ?? []
    }

    private var selectContactPairUserIDs: [String] {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs) var selectedContactPairs: [ContactPair]?
        return selectedContactPairs?.users.map(\.id) ?? []
    }

    // MARK: - Init

    public init() {}

    // MARK: - Get Random PenPals Participant

    public func getRandomPenPalsParticipant() async -> Callback<User, Exception> {
        let getAllUsersResult = await userService.getAllUsers() // TODO: Will need to be a limited query once user numbers pick up.

        switch getAllUsersResult {
        case let .success(users):
            guard let randomPenPalsParticipant = users
                .filter({ !contactPairArchiveUserIDs.contains($0.id) })
                .filter({ !currentUserConversationUserIDs.contains($0.id) })
                .filter({ !selectContactPairUserIDs.contains($0.id) })
                .filter({ $0.isPenPalsParticipant })
                .filter({ $0.languageCode != userSession.currentUser?.languageCode })
                .randomElement() else {
                return .failure(.init(
                    "Failed to resolve random PenPals participant.",
                    isReportable: false,
                    metadata: [self, #file, #function, #line]
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
                metadata: [self, #file, #function, #line]
            )
        }

        let updateValueResult = await currentUser.updateValue(
            didGrantPenPalsPermission,
            forKey: .isPenPalsParticipant
        )

        switch updateValueResult {
        case let .success(user):
            self.didGrantPenPalsPermission = didGrantPenPalsPermission
            Observables.didGrantPenPalsPermission.value = didGrantPenPalsPermission
            return userSession.setCurrentUser(user)

        case let .failure(exception):
            return exception
        }
    }
}
