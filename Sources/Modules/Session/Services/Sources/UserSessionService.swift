//
//  UserSessionService.swift
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

/* 3rd-party */
import FirebaseDatabase

public final class UserSessionService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    public private(set) var currentUser: User?

    @Persistent(.currentUserID) private var currentUserID: String?
    @LockIsolated private var isUpdatingCurrentUser = false

    // MARK: - Computed Properties

    public var offlineCurrentUser: User? {
        get {
            @Persistent(.offlineCurrentUser) var offlineCurrentUser: User?

            guard let currentUserID,
                  let offlineCurrentUser,
                  currentUserID == offlineCurrentUser.id else { return nil }
            return offlineCurrentUser
        }
        set {
            @Persistent(.offlineCurrentUser) var offlineCurrentUser: User?

            guard let newValue else {
                offlineCurrentUser = nil
                return
            }

            guard let currentUserID,
                  newValue.id == currentUserID else { return }
            offlineCurrentUser = newValue
        }
    }

    private var currentUserDatabaseReference: DatabaseReference? {
        guard let currentUser else { return nil }
        return Database.database().reference().child(
            "\(Networking.config.environment.shortString)/\(NetworkPath.users.rawValue)/\(currentUser.id)"
        )
    }

    // MARK: - Object Lifecycle

    deinit {
        if let exception = stopObservingCurrentUserChanges() {
            Logger.log(exception, domain: .userSession)
        }
    }

    // MARK: - Resolve Current User

    public func resolveCurrentUser(_ cacheStrategy: CacheStrategy = .returnCacheOnFailure) async -> Callback<User, Exception> {
        guard let currentUserID else {
            return .failure(.init("Current user ID has not been set.", metadata: [self, #file, #function, #line]))
        }

        if cacheStrategy == .returnCacheFirst,
           let currentUser,
           currentUser.id == currentUserID {
            return .success(currentUser)
        }

        isUpdatingCurrentUser = true

        let getUserResult = await networking.userService.getUser(id: currentUserID)

        switch getUserResult {
        case let .success(user):
            // FIXME: Seeing data races occur here. Fixed using mainQueue.sync for now.
            mainQueue.sync {
                currentUser = user
                self.currentUserID = user.id
            }
            isUpdatingCurrentUser = false
            return .success(user)

        case let .failure(exception):
            isUpdatingCurrentUser = false

            if cacheStrategy == .returnCacheOnFailure,
               let currentUser,
               currentUser.id == currentUserID {
                return .success(currentUser)
            }

            return .failure(exception)
        }
    }

    // MARK: - Set Current User

    public func setCurrentUser(_ user: User) -> Exception? {
        guard let currentUserID,
              user.id == currentUserID else {
            return .init(
                "Either current user ID has not been set, or provided user's ID does not match its value.",
                metadata: [self, #file, #function, #line]
            )
        }

        mainQueue.sync { currentUser = user }
        return nil
    }

    // MARK: - Offline Current User

    public func persistOfflineCurrentUser() {
        offlineCurrentUser = currentUser
    }

    @discardableResult
    public func setOfflineCurrentUser() -> Exception? {
        guard !build.isOnline else {
            return .init(
                "Internet connection is not offline.",
                metadata: [self, #file, #function, #line]
            )
        }

        guard let offlineCurrentUser else {
            return .init(
                "No persisted user exists.",
                metadata: [self, #file, #function, #line]
            )
        }

        currentUser = offlineCurrentUser
        return nil
    }

    // MARK: - Current User Observation

    public func startObservingCurrentUserChanges() {
        guard let currentUserDatabaseReference else { return }
        currentUserDatabaseReference.removeAllObservers()

        Logger.log(
            "Started observing current user changes.",
            domain: .userSession,
            metadata: [self, #file, #function, #line]
        )

        currentUserDatabaseReference.observe(.value) { snapshot in
            guard let currentUser = self.currentUser else { return }
            guard let dictionary = snapshot.value as? [String: Any] else {
                Logger.log(
                    .Networking.typecastFailed("dictionary", metadata: [self, #file, #function, #line]),
                    domain: .userSession
                )
                return
            }

            func updateCurrentUser() {
                Task {
                    if let exception = await self.updateCurrentUser() {
                        Logger.log(exception, domain: .user)
                    }
                }
            }

            guard let updatedConversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { return }
            guard let currentConversationIDStrings = currentUser.conversationIDs?.map(\.encoded) else {
                updateCurrentUser()
                return
            }

            guard currentConversationIDStrings.sorted() != updatedConversationIDStrings.sorted() else {
                guard let updatedBlockedUserIDs = dictionary[User.SerializationKeys.blockedUserIDs.rawValue] as? [String] else { return }
                let currentBlockedUserIDs = currentUser.blockedUserIDs ?? .bangQualifiedEmpty
                guard currentBlockedUserIDs.sorted() != updatedBlockedUserIDs.sorted() else {
                    Logger.log(
                        "Skipping current user update as conversation ID values do not appear to have changed.",
                        domain: .user,
                        metadata: [self, #file, #function, #line]
                    )
                    return
                }

                updateCurrentUser()
                return
            }

            // Remove deleted conversations
            for id in currentConversationIDStrings where !updatedConversationIDStrings.contains(id) {
                self.networking.conversationService.archive.removeValue(idKey: id)
            }

            updateCurrentUser()
        } withCancel: { error in
            Logger.log(.init(error, metadata: [self, #file, #function, #line]), domain: .userSession)
        }
    }

    @discardableResult
    public func stopObservingCurrentUserChanges() -> Exception? {
        guard let currentUserDatabaseReference else {
            return .init("Current user has not been set.", metadata: [self, #file, #function, #line])
        }

        Logger.log(
            "Stopped observing current user changes.",
            domain: .userSession,
            metadata: [self, #file, #function, #line]
        )

        currentUserDatabaseReference.removeAllObservers()
        return nil
    }

    // MARK: - Delete Account

    public func deleteAccount() async -> Exception? {
        guard let currentUserID else {
            return .init("Current user ID has not been set.", metadata: [self, #file, #function, #line])
        }

        let getValuesResult = await networking.database.getValues(at: NetworkPath.deletedUsers.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .Networking.typecastFailed("array", metadata: [self, #file, #function, #line])
            }

            array.append(currentUserID)
            array = array.filter { $0 != .bangQualifiedEmpty }.unique

            if let exception = await networking.database.setValue(array, forKey: NetworkPath.deletedUsers.rawValue) {
                return exception
            }

        case let .failure(exception):
            guard exception.isEqual(to: .Networking.Database.noValueExists) else { return exception }
            if let exception = await networking.database.setValue([currentUserID], forKey: NetworkPath.deletedUsers.rawValue) {
                return exception
            }
        }

        if let exception = await networking.integrityService.resolveSession() {
            return exception
        }

        return await networking.integrityService.repairMalformedUsers([currentUserID]).exception
    }

    // MARK: - Auxiliary

    private func updateCurrentUser() async -> Exception? {
        guard !isUpdatingCurrentUser else {
            Logger.log(
                "Skipping current user update because an update is already occurring.",
                domain: .userSession,
                metadata: [self, #file, #function, #line]
            )
            return nil
        }

        isUpdatingCurrentUser = true
        let resolveCurrentUserResult = await resolveCurrentUser()

        switch resolveCurrentUserResult {
        case .success:
            Logger.log(
                "Updated current user.",
                domain: .userSession,
                metadata: [self, #file, #function, #line]
            )

            Observables.updatedCurrentUser.trigger()
            chatPageState.setIsWaitingToUpdateConversations(chatPageState.isPresented)

            isUpdatingCurrentUser = false
            return nil

        case let .failure(exception):
            isUpdatingCurrentUser = false
            return exception
        }
    }
}
