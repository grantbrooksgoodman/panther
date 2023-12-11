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
    @Persistent(.currentUserID) private var currentUserID: String?

    // MARK: - Methods

    public func setCurrentUser(_ cacheStrategy: CacheStrategy = .disregardCache) async -> Callback<User, Exception> {
        guard let currentUserID else {
            return .failure(.init("Current user ID has not been set.", metadata: [self, #file, #function, #line]))
        }

        if cacheStrategy == .returnCacheFirst,
           let currentUser,
           currentUser.id == currentUserID {
            return .success(currentUser)
        }

        let getUserResult = await userService.getUser(id: currentUserID)

        switch getUserResult {
        case let .success(user):
            currentUser = user
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
}
