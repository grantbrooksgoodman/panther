//
//  UserSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public final class UserSessionService {
    // MARK: - Dependencies

    @Dependency(\.networking.services.user) private var userService: UserService

    // MARK: - Properties

    public private(set) var currentUser: User?
    @Persistent(.currentUserID) private var currentUserID: UserID?

    // MARK: - Set Current User

    public func setCurrentUser(_ cacheStrategy: CacheStrategy = .returnCacheOnFailure) async -> Callback<User, Exception> {
        guard let currentUserID else {
            return .failure(.init("Current user ID has not been set.", metadata: [self, #file, #function, #line]))
        }

        if cacheStrategy == .returnCacheFirst,
           let currentUser,
           currentUser.id == currentUserID {
            return .success(currentUser)
        }

        let getUserResult = await userService.getUser(idKey: currentUserID.key)

        switch getUserResult {
        case let .success(user):
            currentUser = user
            self.currentUserID = user.id
            return .success(user)

        case let .failure(exception):
            if cacheStrategy == .returnCacheOnFailure,
               let currentUser,
               currentUser.id == currentUserID {
                return .success(currentUser)
            }

            return .failure(exception)
        }
    }

    // MARK: - Get Users for Conversation

    public func getUsers(conversation: Conversation) async -> Callback<[User], Exception> {
        let commonParams = ["ConversationID": conversation.id.encoded]

        let userIDKeys = conversation.participants.map(\.userIDKey).filter { $0 != currentUser?.id.key }
        guard !userIDKeys.isBangQualifiedEmpty else {
            let exception = Exception("No participants for this conversation.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let getUsersResult = await userService.getUsers(idKeys: userIDKeys)

        switch getUsersResult {
        case let .success(users):
            guard !users.isEmpty,
                  users.count == userIDKeys.count else {
                let exception = Exception("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            return .success(users)

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }
}
