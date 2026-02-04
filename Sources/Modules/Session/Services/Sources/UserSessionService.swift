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

final class UserSessionService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.storage) private var storageSession: StorageSessionService

    // MARK: - Properties

    // NIT: Should probably be actor-isolated.
    private(set) var currentUser: User?

    @Persistent(.currentUserID) private var currentUserID: String?
    @LockIsolated private var isUpdatingCurrentUser = false

    // MARK: - Computed Properties

    var offlineCurrentUser: User? {
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

    func resolveCurrentUser(_ cacheStrategy: CacheStrategy = .returnCacheOnFailure) async -> Callback<User, Exception> {
        guard let currentUserID else {
            return .failure(.init("Current user ID has not been set.", metadata: .init(sender: self)))
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
            core.gcd.syncOnMain {
                self.currentUser = user
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

    func setCurrentUser(
        _ user: User?,
        repopulateValuesIfNeeded: Bool = false
    ) -> Exception? {
        defer { // NIT: This seems fishy/unsafe.
            Task {
                guard repopulateValuesIfNeeded,
                      currentUser != nil,
                      user?.id == currentUserID else { return }

                if let exception = await User.populateCurrentUserConversationsIfNeeded() {
                    Logger.log(
                        exception,
                        domain: .userSession,
                        with: .toast
                    )
                }
            }
        }

        if let user {
            guard let currentUserID,
                  user.id == currentUserID else {
                return .init(
                    "Either current user ID has not been set, or provided user's ID does not match its value.",
                    metadata: .init(sender: self)
                )
            }

            core.gcd.syncOnMain { self.currentUser = user }
            return nil
        }

        core.gcd.syncOnMain { self.currentUser = user }
        return nil
    }

    // MARK: - Offline Current User

    func persistOfflineCurrentUser() {
        offlineCurrentUser = currentUser
    }

    @discardableResult
    func setOfflineCurrentUser() -> Exception? {
        guard !build.isOnline else {
            return .init(
                "Internet connection is not offline.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        guard let offlineCurrentUser else {
            return .init(
                "No persisted user exists.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        currentUser = offlineCurrentUser
        return nil
    }

    // MARK: - Resolve & Set Language Code

    @discardableResult
    func resolveAndSetLanguageCode() async -> Exception? {
        guard let currentUserID else {
            return .init(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        let getValuesResult = await networking.database.getValues(
            at: "\(NetworkPath.users.rawValue)/\(currentUserID)/\(User.SerializationKey.languageCode.rawValue)"
        )

        switch getValuesResult {
        case let .success(values):
            guard let string = values as? String else {
                return .Networking.typecastFailed("string", metadata: .init(sender: self))
            }

            Logger.log(
                "Setting language code to \(string.englishLanguageName ?? string.uppercased()).",
                domain: .userSession,
                sender: self
            )

            core.utils.setLanguageCode(string)
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Current User Observation

    func startObservingCurrentUserChanges() {
        guard let currentUserDatabaseReference else { return }
        currentUserDatabaseReference.removeAllObservers()

        Logger.log(
            "Started observing current user changes.",
            domain: .userSession,
            sender: self
        )

        currentUserDatabaseReference.observe(.value) { snapshot in
            guard let currentUser = self.currentUser else { return }
            guard let dictionary = snapshot.value as? [String: Any] else {
                Logger.log(
                    .Networking.typecastFailed("dictionary", metadata: .init(sender: self)),
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
                        sender: self
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
            Logger.log(.init(error, metadata: .init(sender: self)), domain: .userSession)
        }
    }

    @discardableResult
    func stopObservingCurrentUserChanges() -> Exception? {
        guard let currentUserDatabaseReference else {
            return .init("Current user has not been set.", metadata: .init(sender: self))
        }

        Logger.log(
            "Stopped observing current user changes.",
            domain: .userSession,
            sender: self
        )

        currentUserDatabaseReference.removeAllObservers()
        return nil
    }

    // MARK: - Auxiliary

    private func updateCurrentUser() async -> Exception? {
        guard !isUpdatingCurrentUser else {
            Logger.log(
                "Skipping current user update because an update is already occurring.",
                domain: .userSession,
                sender: self
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
                sender: self
            )

            storageSession.invalidateDataUsageCalculation()
            _ = await storageSession.getCurrentUserDataUsage()

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
