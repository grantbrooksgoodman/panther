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

    private var currentUserConversationUsers: [User] {
        userSession
            .currentUser?
            .conversations?
            .visibleForCurrentUser
            .compactMap(\.users)
            .reduce([], +)
            .unique ?? []
    }

    // MARK: - Init

    public init() {}

    // MARK: - Get Random PenPals Participant

    public func getRandomPenPalsParticipant() async -> Callback<User, Exception> {
        let getAllUsersResult = await userService.getAllUsers()

        switch getAllUsersResult {
        case let .success(users):
            guard let randomPenPalsParticipant = users
                .filter({ !currentUserConversationUsers.contains($0) })
                .filter({ $0.isPenPalsParticipant })
                .filter({ $0.languageCode != userSession.currentUser?.languageCode })
                .randomElement() else {
                return .failure(.init(
                    "Failed to resolve random PenPals participant.",
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
