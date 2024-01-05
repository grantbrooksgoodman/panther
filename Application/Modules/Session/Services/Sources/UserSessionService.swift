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
import FirebaseDatabase
import Redux

public final class UserSessionService {
    // MARK: - Dependencies

    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    public private(set) var currentUser: User?
    @Persistent(.currentUserID) private var currentUserID: UserID?

    // MARK: - Computed Properties

    private var hashDatabaseReference: DatabaseReference? {
        guard let currentUser else { return nil }

        let pathPrefix = "\(networking.config.environment.shortString)/\(networking.config.paths.users)"
        return firebaseDatabase.child(
            "\(pathPrefix)/\(currentUser.id.key)/\(User.SerializationKeys.compressedHash.rawValue)"
        )
    }

    // MARK: - Object Lifecycle

    deinit {
        if let exception = stopObservingHashValueChanges() {
            Logger.log(exception)
        }
    }

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

        let getUserResult = await networking.services.user.getUser(idKey: currentUserID.key)

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

    // MARK: - Hash Value Observation

    public func startObservingHashValueChanges() {
        guard let currentUser,
              let hashDatabaseReference else { return }

        hashDatabaseReference.observe(.value) { snapshot in
            guard let hash = snapshot.value as? String,
                  hash != currentUser.id.hash else { return }

            Task {
                let setCurrentUserResult = await self.setCurrentUser()

                switch setCurrentUserResult {
                case let .success(user):
                    Logger.log(
                        "Updated current user.\nPrevious hash: \(currentUser.id.hash)\nNew hash: \(user.id.hash)",
                        domain: .user,
                        metadata: [self, #file, #function, #line]
                    )

                case let .failure(exception):
                    Logger.log(exception, domain: .user)
                }
            }
        } withCancel: { error in
            Logger.log(.init(error, metadata: [self, #file, #function, #line]), domain: .user)
        }
    }

    @discardableResult
    public func stopObservingHashValueChanges() -> Exception? {
        guard let hashDatabaseReference else {
            return .init("Current user has not been set.", metadata: [self, #file, #function, #line])
        }

        hashDatabaseReference.removeAllObservers()
        return nil
    }

    // MARK: - Get Users for Conversation

    public func getUsers(conversation: Conversation) async -> Callback<[User], Exception> {
        let commonParams = ["ConversationID": conversation.id.encoded]

        let userIDKeys = conversation.participants.map(\.userIDKey).filter { $0 != currentUser?.id.key }
        guard !userIDKeys.isBangQualifiedEmpty else {
            let exception = Exception("No participants for this conversation.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let getUsersResult = await networking.services.user.getUsers(idKeys: userIDKeys)

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

    // MARK: - Update Push Tokens

    public func updatePushTokens() async -> Exception? {
        guard let pushToken = notificationService.pushToken else {
            return .init("Push token has not been set.", metadata: [self, #file, #function, #line])
        }

        var pushTokens = currentUser?.pushTokens ?? []
        guard !pushTokens.contains(pushToken) else {
            return .init("Push tokens already up to date.", metadata: [self, #file, #function, #line])
        }

        pushTokens.append(pushToken)
        let updateValueResult = await currentUser?.updateValue(pushTokens, forKey: .pushTokens)

        switch updateValueResult {
        case let .success(user):
            currentUser = user
            currentUserID = user.id
            return nil

        case let .failure(exception):
            return exception

        case .none:
            return nil
        }
    }
}
