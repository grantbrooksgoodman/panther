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

final class UserSessionService: @unchecked Sendable {
    // MARK: - Types

    private enum TaskID: String {
        case getDataUsage
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.build.isOnline) private var isOnline: Bool
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.sessionStore) private var store: SessionStore
    @Dependency(\.clientSession.storage) private var storageSession: StorageSessionService
    @Dependency(\.timestampDateFormatter) private var timestampDateFormatter: DateFormatter

    // MARK: - Properties

    @Persistent(.currentUserID) private var currentUserID: String?
    @LockIsolated private var isUpdatePending = false
    @LockIsolated private var isUpdatingCurrentUser = false
    private var observationTask: Task<Void, Never>?
    private var _currentUser = LockIsolated<User?>(nil)

    private static let coalescer = SingleSlotCoalescer<Void>()

    // MARK: - Computed Properties

    private(set) var currentUser: User? {
        get { _currentUser.wrappedValue }
        set { _currentUser.wrappedValue = newValue }
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
        do {
            try stopObservingCurrentUserChanges()
        } catch {
            Logger.log(
                error,
                domain: .userSession
            )
        }
    }

    // MARK: - Hydrate Current User Conversations

    /// Hydrates conversations for the current user from the archive, sync, or network.
    ///
    /// This replaces the former `User.setConversations()` instance method, which relied
    /// on reference-type self-mutation. The logic is identical, but operates on value-type
    /// copies and commits the result back to `currentUser`.
    func hydrateCurrentUserConversations() async throws(Exception) {
        let hydrateConversations: @Sendable () async throws(Exception) -> Void = {
            try await self._hydrateCurrentUserConversations()
        }

        try await Self.coalescer(
            mode: .lastCallerWins,
            hydrateConversations
        )
    }

    /// Fetches users for all visible conversations on the current user and writes
    /// the hydrated conversations back to `currentUser`.
    ///
    /// With struct-based models, `settingUsers()` returns new values rather than
    /// mutating in place. This method ensures the hydrated results are stored.
    func hydrateUsersOnCurrentUserConversations() async throws(Exception) {
        guard let user = currentUser,
              let conversations = user.conversations else { return }

        let hydrated = try await conversations
            .visibleForCurrentUser
            .settingUsers()

        let remaining = conversations.filter { conversation in
            !hydrated.contains(where: { $0.id.key == conversation.id.key })
        }

        currentUser = user.settingConversations(Set(hydrated + remaining))
    }

    private func _hydrateCurrentUserConversations() async throws(Exception) {
        @Dependency(\.networking.conversationService) var conversationService: ConversationService

        guard !Task.isCancelled,
              let user = currentUser,
              user.id == User.currentUserID,
              var conversationIDs = user.conversationIDs else { return }

        var conversationsNeedingFetch = Set<ConversationID>()
        var conversationsNeedingUpdate = Set<Conversation>()
        var decodedConversations = Set<Conversation>()

        @Persistent(.conversationArchive) var conversationArchive: Set<Conversation>?
        let ignoredConversations = conversationArchive?
            .filter { !$0.isVisibleForCurrentUser }
            .map(\.id.key) ?? []
        conversationIDs = conversationIDs.filter { !ignoredConversations.contains($0.key) }

        for conversationID in conversationIDs {
            guard !Task.isCancelled else { return }
            if let value = conversationService.archive.getValue(id: conversationID) {
                decodedConversations.merge(with: [value])
            } else if let value = conversationService.archive.getValue(idKey: conversationID.key) {
                conversationsNeedingUpdate.insert(value)
            } else {
                conversationsNeedingFetch.insert(conversationID)
            }
        }

        guard !Task.isCancelled else { return }
        Logger.log(
            // swiftlint:disable:next line_length
            "Conversations needing update: \(conversationsNeedingUpdate.count)\nConversations needing fetch: \(conversationsNeedingFetch.count)\nIgnored conversations: \(ignoredConversations.count)\nDecoded conversations: \(decodedConversations.count)",
            domain: .user,
            sender: self
        )

        if conversationsNeedingFetch.isEmpty,
           conversationsNeedingUpdate.isEmpty {
            if let existingConversations = user.conversations,
               !existingConversations.isEmpty,
               Set(existingConversations) == decodedConversations {
                return
            }

            return commitConversationsToMemory(
                decodedConversations,
                for: user
            )
        }

        guard !Task.isCancelled else { return }
        try await decodedConversations.merge(
            with: conversationsNeedingUpdate.parallelMap {
                @Dependency(\.clientSession.conversation.sync) var conversationSyncService: ConversationSyncService
                return try await conversationSyncService.synchronizeConversation($0)
            }
        )

        guard !conversationsNeedingFetch.isEmpty else {
            try validateRatio(
                decodedConversations,
                conversationIDs
            )

            return commitConversationsToMemory(
                decodedConversations,
                for: user
            )
        }

        guard !Task.isCancelled else { return }
        let conversations = try await conversationService.getConversations(
            idKeys: conversationsNeedingFetch.map(\.key)
        )

        decodedConversations.merge(with: conversations)
        try validateRatio(
            decodedConversations,
            conversationIDs
        )

        commitConversationsToMemory(
            decodedConversations,
            for: user
        )
    }

    // MARK: - Resolve Current User

    func resolveCurrentUser(
        _ cacheStrategy: CacheStrategy = .returnCacheOnFailure
    ) async throws(Exception) -> User {
        guard let currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        if cacheStrategy == .returnCacheFirst,
           let currentUser,
           currentUser.id == currentUserID {
            return currentUser
        }

        do {
            var user = try await networking.userService.getUser(id: currentUserID)
            user = user.inheritingLocalState(from: currentUser)
            currentUser = user
            await store.setCurrentUserID(user.id)
            await store.upsertUser(user)
            await MainActor.run { self.currentUserID = user.id }
            return user
        } catch {
            if cacheStrategy == .returnCacheOnFailure,
               let currentUser,
               currentUser.id == currentUserID {
                return currentUser
            }

            throw error
        }
    }

    // MARK: - Set Current User

    func setCurrentUser(
        _ user: User?,
        repopulateValuesIfNeeded: Bool = false
    ) throws(Exception) {
        defer { // NIT: This seems fishy/unsafe.
            Task {
                guard repopulateValuesIfNeeded,
                      currentUser != nil,
                      user?.id == currentUserID else { return }

                do throws(Exception) {
                    try await User.populateCurrentUserConversationsIfNeeded()
                } catch {
                    Logger.log(
                        error,
                        domain: .userSession,
                        with: .toast
                    )
                }
            }
        }

        if let user {
            guard let currentUserID,
                  user.id == currentUserID else {
                throw Exception(
                    "Either current user ID has not been set, or provided user's ID does not match its value.",
                    metadata: .init(sender: self)
                )
            }

            currentUser = user
            Task { await store.upsertUser(user) }
            return
        }

        currentUser = user
    }

    // MARK: - Offline Current User

    func persistOfflineCurrentUser() {
        offlineCurrentUser = currentUser
    }

    func setOfflineCurrentUser() throws(Exception) {
        guard !isOnline else {
            throw Exception(
                "Internet connection is not offline.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        guard let offlineCurrentUser else {
            throw Exception(
                "No persisted user exists.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        currentUser = offlineCurrentUser
        Task {
            await store.setCurrentUserID(offlineCurrentUser.id)
            await store.upsertUser(offlineCurrentUser)
        }
    }

    // MARK: - Resolve & Set Language Code

    func resolveAndSetLanguageCode() async throws(Exception) {
        guard let currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        let languageCode: String = try await networking.database.getValues(
            at: [
                NetworkPath.users.rawValue,
                currentUserID,
                User.SerializableKey.languageCode.rawValue,
            ].joined(separator: "/")
        )

        Logger.log(
            "Setting language code to \(languageCode.englishLanguageName ?? languageCode.uppercased()).",
            domain: .userSession,
            sender: self
        )

        coreUtilities.setLanguageCode(languageCode)
    }

    // MARK: - Current User Observation

    func startObservingCurrentUserChanges() {
        guard let currentUserID = currentUser?.id else { return }
        observationTask?.cancel()
        observationTask = nil

        Logger.log(
            "Started observing current user changes.",
            domain: .userSession,
            sender: self
        )

        observationTask = Task {
            do {
                for try await dictionary: [String: Any] in networking.database.observe(
                    at: [
                        NetworkPath.users.rawValue,
                        currentUserID,
                    ].joined(separator: "/")
                ) {
                    if blockedUserIDsDidChange(dictionary) ||
                        conversationsDidChange(dictionary) {
                        updateCurrentUser()
                    } else if lastSignedInDateDidChange(dictionary) {
                        signOutToPreserveSingleActiveUser()
                    } else {
                        Logger.log(
                            "Skipping current user update as relevant values do not appear to have changed.",
                            domain: .userSession,
                            sender: self
                        )
                    }
                }
            } catch {
                Logger.log(
                    .init(
                        error,
                        metadata: .init(sender: self)
                    ),
                    domain: .userSession
                )
            }
        }
    }

    func stopObservingCurrentUserChanges() throws(Exception) {
        guard observationTask != nil else {
            throw Exception(
                "No active observers to stop.",
                metadata: .init(sender: self)
            )
        }

        Logger.log(
            "Stopped observing current user changes.",
            domain: .userSession,
            sender: self
        )

        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Auxiliary

    private func blockedUserIDsDidChange(_ dictionary: [String: Any]) -> Bool {
        let currentBlockedUserIDs = (currentUser?.blockedUserIDs ?? .bangQualifiedEmpty).sorted()

        guard let updatedBlockedUserIDs = (dictionary[
            User.SerializableKey.blockedUserIDs.rawValue
        ] as? [String])?.sorted() else { return false }

        return currentBlockedUserIDs != updatedBlockedUserIDs
    }

    private func commitConversationsToMemory(
        _ conversations: Set<Conversation>,
        for user: User
    ) {
        @Dependency(\.networking.conversationService.archive) var conversationArchive: ConversationArchiveService

        guard !Task.isCancelled else { return }
        let updatedUser = user.settingConversations(conversations)
        currentUser = updatedUser
        conversationArchive.addValues(conversations)

        Task {
            await store.upsertUser(updatedUser)
            await store.upsertConversations(Array(conversations))
        }
    }

    private func conversationsDidChange(_ dictionary: [String: Any]) -> Bool {
        guard let currentConversationIDStrings = currentUser?
            .conversationIDs?
            .map(\.encoded)
            .sorted() else { return true }

        guard let updatedConversationIDStrings = (dictionary[
            User.SerializableKey.conversationIDs.rawValue
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
            User.SerializableKey.lastSignedIn.rawValue
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

            Application.reset(
                onCompletion: .navigateToSplash
            )
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
                $isUpdatePending.withValue { $0 = true }
                return Logger.log(
                    "Queuing pending current user update because an update is already occurring.",
                    domain: .userSession,
                    sender: self
                )
            }

            do throws(Exception) {
                _ = try await resolveCurrentUser()
                Logger.log(
                    "Updated current user.",
                    domain: .userSession,
                    sender: self
                )

                do throws(Exception) {
                    try await hydrateCurrentUserConversations()
                } catch {
                    Logger.log(
                        error,
                        domain: .userSession
                    )
                }

                Task.debounced(
                    "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.getDataUsage.rawValue)",
                    delay: .seconds(5),
                    priority: .utility
                ) {
                    self.coreUtilities.clearCaches([.user])
                    _ = try? await self.storageSession.getCurrentUserDataUsage()
                }

                Observables.updatedCurrentUser.trigger()
                chatPageState.setIsWaitingToUpdateConversations(
                    chatPageState.isPresented
                )
            } catch {
                Logger.log(
                    error,
                    domain: .userSession
                )
            }

            var shouldRetry = false
            $isUpdatePending.withValue {
                shouldRetry = $0
                $0 = false
            }

            self.isUpdatingCurrentUser = false
            guard shouldRetry else { return }

            Logger.log(
                "Retrying current user update from pending request.",
                domain: .userSession,
                sender: self
            )

            updateCurrentUser()
        }
    }

    private func validateRatio(
        _ firstComparator: any Collection,
        _ secondComparator: any Collection
    ) throws(Exception) {
        guard firstComparator.count == secondComparator.count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }
    }
}

private extension String {
    var idKey: String {
        components(separatedBy: " ").first ?? self
    }
}

// swiftlint:enable file_length type_body_length
