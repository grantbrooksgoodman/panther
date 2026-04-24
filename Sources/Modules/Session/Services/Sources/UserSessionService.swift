//
//  UserSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/* 3rd-party */
import FirebaseDatabase

final class UserSessionService: @unchecked Sendable {
    // MARK: - Types

    private enum TaskID: Hashable {
        case getDataUsage
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.build.isOnline) private var isOnline: Bool
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.storage) private var storageSession: StorageSessionService
    @Dependency(\.timestampDateFormatter) private var timestampDateFormatter: DateFormatter

    // MARK: - Properties

    @Persistent(.currentUserID) private var currentUserID: String?
    @LockIsolated private var isUpdatingCurrentUser = false
    private var _currentUser = LockIsolated<User?>(nil)

    // MARK: - Computed Properties

    private(set) var currentUser: User? {
        get { _currentUser.wrappedValue }
        set { _currentUser.wrappedValue = newValue }
    }

    private var currentUserDatabaseReference: DatabaseReference? {
        guard let currentUser else { return nil }
        return Database.database().reference().child(
            "\(Networking.config.environment.shortString)/\(NetworkPath.users.rawValue)/\(currentUser.id)"
        )
    }

    private var offlineCurrentUser: User? {
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

    // MARK: - Object Lifecycle

    deinit {
        if let exception = stopObservingCurrentUserChanges() {
            Logger.log(
                exception,
                domain: .userSession
            )
        }
    }

    // MARK: - Resolve Current User

    func resolveCurrentUser(
        _ cacheStrategy: CacheStrategy = .returnCacheOnFailure
    ) async -> Callback<User, Exception> {
        guard let currentUserID else {
            return .failure(.init("Current user ID has not been set.", metadata: .init(sender: self)))
        }

        if cacheStrategy == .returnCacheFirst,
           let currentUser,
           currentUser.id == currentUserID {
            return .success(currentUser)
        }

        let getUserResult = await networking.userService.getUser(id: currentUserID)

        switch getUserResult {
        case let .success(user):
            currentUser = user
            await MainActor.run { self.currentUserID = user.id }
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

            currentUser = user
            return nil
        }

        currentUser = user
        return nil
    }

    // MARK: - Offline Current User

    func persistOfflineCurrentUser() {
        offlineCurrentUser = currentUser
    }

    @discardableResult
    func setOfflineCurrentUser() -> Exception? {
        guard !isOnline else {
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

            coreUtilities.setLanguageCode(string)
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
            guard let dictionary = snapshot.value as? [String: Any] else {
                return Logger.log(
                    .Networking.typecastFailed(
                        "dictionary",
                        metadata: .init(sender: self)
                    ),
                    domain: .userSession
                )
            }

            if self.blockedUserIDsDidChange(dictionary) ||
                self.conversationsDidChange(dictionary) {
                return self.updateCurrentUser()
            } else if self.lastSignedInDateDidChange(dictionary) {
                return self.signOutToPreserveSingleActiveUser()
            }

            return Logger.log(
                "Skipping current user update as relevant values do not appear to have changed.",
                domain: .userSession,
                sender: self
            )
        } withCancel: { error in
            Logger.log(
                .init(
                    error,
                    metadata: .init(sender: self)
                ),
                domain: .userSession
            )
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

    private func blockedUserIDsDidChange(_ dictionary: [String: Any]) -> Bool {
        let currentBlockedUserIDs = (currentUser?.blockedUserIDs ?? .bangQualifiedEmpty).sorted()

        guard let updatedBlockedUserIDs = (dictionary[
            User.SerializationKeys.blockedUserIDs.rawValue
        ] as? [String])?.sorted() else { return false }

        return currentBlockedUserIDs != updatedBlockedUserIDs
    }

    private func conversationsDidChange(_ dictionary: [String: Any]) -> Bool {
        guard let currentConversationIDStrings = currentUser?
            .conversationIDs?
            .map(\.encoded)
            .sorted() else { return true }

        guard let updatedConversationIDStrings = (dictionary[
            User.SerializationKeys.conversationIDs.rawValue
        ] as? [String])?.sorted() else { return false }

        // Remove deleted conversations.
        for idKey in currentConversationIDStrings
            .map(\.idKey) where !updatedConversationIDStrings
            .map(\.idKey)
            .contains(idKey) {
            networking.conversationService.archive.removeValue(
                idKey: idKey
            )
        }

        return currentConversationIDStrings != updatedConversationIDStrings
    }

    private func lastSignedInDateDidChange(_ dictionary: [String: Any]) -> Bool {
        let currentLastSignedInDate = currentUser?.lastSignedIn
        let updatedLastSignedInString = dictionary[
            User.SerializationKeys.lastSignedIn.rawValue
        ] as? String

        guard let updatedLastSignedInString,
              let updatedLastSignedInDate = timestampDateFormatter.date(
                  from: updatedLastSignedInString
              ) else { return false }

        return !(currentLastSignedInDate?.isWithinSameSecond(as: updatedLastSignedInDate) ?? true)
    }

    private func signOutToPreserveSingleActiveUser() {
        Task { @MainActor in
            Toast.show(
                .init(
                    .banner(style: .info),
                    title: "You have been signed out.",
                    message: "A sign-in was detected from another device."
                ),
                translating: Toast.TranslationOptionKey.allCases
            )

            RuntimeStorage.store(false, as: .updatedLastSignInDate)
            Application.reset(onCompletion: .navigateToSplash)
        }
    }

    private func updateCurrentUser() {
        Task {
            var isUpdatingCurrentUser = false
            $isUpdatingCurrentUser.withValue {
                isUpdatingCurrentUser = $0
                if !$0 { $0 = true }
            }

            guard !isUpdatingCurrentUser else {
                return Logger.log(
                    "Skipping current user update because an update is already occurring.",
                    domain: .userSession,
                    sender: self
                )
            }

            let resolveCurrentUserResult = await resolveCurrentUser()

            switch resolveCurrentUserResult {
            case .success:
                Logger.log(
                    "Updated current user.",
                    domain: .userSession,
                    sender: self
                )

                Task.debounced(
                    TaskID.getDataUsage,
                    delay: .seconds(5),
                    priority: .utility
                ) {
                    self.coreUtilities.clearCaches([.user])
                    _ = await self.storageSession.getCurrentUserDataUsage()
                }

                Observables.updatedCurrentUser.trigger()
                chatPageState.setIsWaitingToUpdateConversations(chatPageState.isPresented)

                self.isUpdatingCurrentUser = false

            case let .failure(exception):
                Logger.log(
                    exception,
                    domain: .userSession
                )

                self.isUpdatingCurrentUser = false
            }
        }
    }
}

private extension String {
    var idKey: String {
        components(separatedBy: " ").first ?? self
    }
}

// swiftlint:enable file_length type_body_length
