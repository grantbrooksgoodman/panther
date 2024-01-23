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
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    public private(set) var currentUser: User?
    @Persistent(.currentUserID) private var currentUserID: String?

    // MARK: - Computed Properties

    private var hashDatabaseReference: DatabaseReference? {
        guard let currentUser else { return nil }

        let pathPrefix = "\(networking.config.environment.shortString)/\(networking.config.paths.users)"
        return firebaseDatabase.child(
            "\(pathPrefix)/\(currentUser.id)/\(User.SerializationKeys.conversationIDs.rawValue)"
        )
    }

    // MARK: - Object Lifecycle

    deinit {
        if let exception = stopObservingConversationHashValueChanges() {
            Logger.log(exception, domain: .user)
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

        let getUserResult = await networking.services.user.getUser(id: currentUserID)

        switch getUserResult {
        case let .success(user):
            // FIXME: Seeing data races occur here. Fixed using mainQueue.sync for now.
            mainQueue.sync {
                currentUser = user
                self.currentUserID = user.id
            }
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

    // MARK: - Conversation Hash Value Observation

    public func startObservingConversationHashValueChanges() {
        guard let currentUser,
              let hashDatabaseReference else { return }

        hashDatabaseReference.observe(.value) { snapshot in
            func updateCurrentUser() {
                // FIXME: Previously protected by a guard clause ensuring an update was not already occurring.
                Task { /* @MainActor in */
                    let setCurrentUserResult = await self.setCurrentUser()

                    switch setCurrentUserResult {
                    case .success:
                        Logger.log(
                            "Updated current user.",
                            domain: .user,
                            metadata: [self, #file, #function, #line]
                        )

                        Observables.updatedCurrentUser.trigger()

                    case let .failure(exception):
                        Logger.log(exception, domain: .user)
                    }
                }
            }

            guard let updatedConversationIDStrings = snapshot.value as? [String] else { return }
            guard let currentConversationIDStrings = currentUser.conversationIDs?.map(\.encoded) else {
                updateCurrentUser()
                return
            }

            guard !currentConversationIDStrings.containsAllStrings(in: updatedConversationIDStrings) else {
                Logger.log(
                    "Skipping current user update as values do not appear to have changed.",
                    domain: .user,
                    metadata: [self, #file, #function, #line]
                )
                return
            }

            for id in currentConversationIDStrings where !updatedConversationIDStrings.contains(id) {
                self.networking.services.conversation.archive.removeValue(idKey: id)
            }

            updateCurrentUser()
        } withCancel: { error in
            Logger.log(.init(error, metadata: [self, #file, #function, #line]), domain: .user)
        }
    }

    @discardableResult
    public func stopObservingConversationHashValueChanges() -> Exception? {
        guard let hashDatabaseReference else {
            return .init("Current user has not been set.", metadata: [self, #file, #function, #line])
        }

        hashDatabaseReference.removeAllObservers()
        return nil
    }

    // MARK: - Get Users for Conversation

    public func getUsers(conversation: Conversation) async -> Callback<[User], Exception> {
        let commonParams = ["ConversationID": conversation.id.encoded]

        let userIDs = conversation.participants.map(\.userID).filter { $0 != currentUserID }
        guard !userIDs.isBangQualifiedEmpty else {
            let exception = Exception("No participants for this conversation.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let getUsersResult = await networking.services.user.getUsers(ids: userIDs)

        switch getUsersResult {
        case let .success(users):
            guard !users.isEmpty,
                  users.count == userIDs.count else {
                let exception = Exception("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            return .success(users)

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    // MARK: - Reset Push Tokens

    @discardableResult
    public func resetPushTokens() async -> Exception? {
        notificationService.setPushToken(nil)

        guard currentUser?.pushTokens != nil else {
            return .init("Push token has not been set.", metadata: [self, #file, #function, #line])
        }

        let updateValueResult = await currentUser?.updateValue(Array.bangQualifiedEmpty, forKey: .pushTokens)

        switch updateValueResult {
        case let .success(user):
            mainQueue.sync {
                currentUser = user
                self.currentUserID = user.id
            }
            return nil

        case let .failure(exception):
            return exception

        case .none:
            return nil
        }
    }

    // MARK: - Update Push Tokens

    @discardableResult
    public func updatePushTokens() async -> Exception? {
        guard let pushToken = notificationService.pushToken else {
            return .init("Push token has not been set.", metadata: [self, #file, #function, #line])
        }

        var pushTokens = currentUser?.pushTokens ?? []
        guard !pushTokens.contains(pushToken) else {
            return .init("Push tokens already up to date.", metadata: [self, #file, #function, #line])
        }

        pushTokens.append(pushToken)
        let updateValueResult = await currentUser?.updateValue(pushTokens.unique, forKey: .pushTokens)

        switch updateValueResult {
        case let .success(user):
            mainQueue.sync {
                currentUser = user
                self.currentUserID = user.id
            }
            return nil

        case let .failure(exception):
            return exception

        case .none:
            return nil
        }
    }
}
