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

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.build.isOnline) private var isOnline: Bool
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.timestampDateFormatter) private var timestampDateFormatter: DateFormatter

    // MARK: - Properties

    private static let conversationCoalescer = SingleSlotCoalescer<Void>()
    private static let messageCoalescer = SingleSlotCoalescer<Void>()
    private static let userCoalescer = SingleSlotCoalescer<Void>()

    @Persistent(.currentUserID) private var currentUserID: String?
    @LockIsolated private var isUpdatePending = false
    @LockIsolated private var isUpdatingCurrentUser = false
    private var observationTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var currentUser: User? {
        guard let currentUserID else { return nil }
        return clientSession.store.users[currentUserID]
    }

    // MARK: - Resolve Current User

    /// Fetches the current user from the server and upserts it
    /// to the session store, optionally resolving associated
    /// data.
    ///
    /// Pass one or more ``User/DataType`` values to indicate
    /// which associated data to resolve after the user itself
    /// is fetched. Each data type is coalesced independently,
    /// so concurrent calls converge rather than duplicate work.
    ///
    /// ```swift
    /// try await userSession.resolveCurrentUser(
    ///     and: [.conversations, .messages, .users]
    /// )
    /// ```
    ///
    /// - Parameter data: The set of associated data types to
    ///   resolve. Pass an empty set to resolve only the user.
    func resolveCurrentUser(
        and data: Set<User.DataType> = []
    ) async throws(Exception) {
        try await resolveCurrentUser()

        if data.contains(.conversations) {
            let resolveConversations: @Sendable () async throws(Exception) -> Void = {
                try await self.resolveCurrentUserConversations()
            }

            try await Self.conversationCoalescer(
                mode: .lastCallerWins,
                resolveConversations
            )
        }

        if data.contains(.messages) {
            let resolveMessages: @Sendable () async throws(Exception) -> Void = {
                try await self.resolveMessagesOnCurrentUserConversations()
            }

            try await Self.messageCoalescer(
                mode: .lastCallerWins,
                resolveMessages
            )
        }

        if data.contains(.users) {
            let resolveUsers: @Sendable () async throws(Exception) -> Void = {
                try await self.resolveUsersOnCurrentUserConversations()
            }

            try await Self.userCoalescer(
                mode: .lastCallerWins,
                resolveUsers
            )
        }
    }

    // MARK: - Current User Observation

    func startObservingCurrentUserChanges(
        enableChangeEmission: Bool = false
    ) {
        guard let currentUserID = currentUser?.id else { return }
        observationTask?.cancel()
        observationTask = nil

        if enableChangeEmission {
            SessionStore.setChangeEmissionSuppressed(false)
        }

        Logger.log(
            "Started observing current user changes.",
            domain: .userSession,
            sender: self
        )

        observationTask = Task {
            do {
                for try await dictionary: [String: Any] in networking.database.observe(
                    path: [
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

    func stopObservingCurrentUserChanges(
        disableChangeEmission: Bool = false
    ) {
        if disableChangeEmission {
            SessionStore.setChangeEmissionSuppressed(true)
        }

        if observationTask == nil {
            Logger.log(
                .init(
                    "No active observers to stop.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ),
                domain: .userSession
            )
        } else {
            Logger.log(
                "Stopped observing current user changes.",
                domain: .userSession,
                sender: self
            )
        }

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
        _ conversations: Set<Conversation>
    ) {
        guard !Task.isCancelled else { return }
        // Resolved from archive or network; bypasses RemotelyUpdatable.update.
        clientSession.store.upsertConversations(conversations)
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
            clientSession.store.removeConversation(idKey: idKey)
        }

        return currentConversationIDStrings != updatedConversationIDStrings
    }

    private func lastSignedInDateDidChange(_ dictionary: [String: Any]) -> Bool {
        let currentLastSignedInDate = RuntimeStorage.lastSignInDate ?? currentUser?.lastSignedIn
        let updatedLastSignedInString = dictionary[
            User.SerializableKey.lastSignedIn.rawValue
        ] as? String

        guard let updatedLastSignedInString,
              let updatedLastSignedInDate = timestampDateFormatter.date(
                  from: updatedLastSignedInString
              ) else { return false }

        return !(currentLastSignedInDate?.isWithinSameSecond(as: updatedLastSignedInDate) ?? true)
    }

    /// Fetches the current user from the server and upserts
    /// the result to the session store.
    private func resolveCurrentUser() async throws(Exception) {
        guard let currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        do {
            // Fetched from server; bypasses RemotelyUpdatable.update.
            try await clientSession.store.upsertUser(
                networking.userService.getUser(
                    id: currentUserID
                )
            )
        } catch {
            throw error
        }
    }

    /// Populates conversations for the current user from the
    /// archive, sync service, or network.
    ///
    /// Conversations already present in the archive are used
    /// directly. Conversations whose identifier matches an
    /// archived entry but whose hash has changed are
    /// synchronized. Remaining conversations are fetched from
    /// the network. The resolved set is committed to the
    /// session store.
    ///
    /// This method resolves conversation objects only; it does
    /// not fetch their associated messages or users.
    private func resolveCurrentUserConversations() async throws(Exception) {
        @Dependency(\.networking.conversationService) var conversationService: ConversationService

        guard !Task.isCancelled,
              let user = currentUser,
              user.id == User.currentUserID,
              var conversationIDs = user.conversationIDs else { return }

        var conversationsNeedingFetch = Set<ConversationID>()
        var conversationsNeedingUpdate = Set<Conversation>()
        var decodedConversations = Set<Conversation>()

        let ignoredConversationIDKeys = clientSession.store.ignoredConversationIDKeys
        conversationIDs = conversationIDs.filter { !ignoredConversationIDKeys.contains($0.key) }

        for conversationID in conversationIDs {
            guard !Task.isCancelled else { return }
            if let value = clientSession.store.getConversation(id: conversationID) {
                decodedConversations.merge(with: [value])
            } else if let value = clientSession.store.getConversation(idKey: conversationID.key) {
                conversationsNeedingUpdate.insert(value)
            } else {
                conversationsNeedingFetch.insert(conversationID)
            }
        }

        guard !Task.isCancelled else { return }
        Logger.log(
            // swiftlint:disable:next line_length
            "Conversations needing update: \(conversationsNeedingUpdate.count)\nConversations needing fetch: \(conversationsNeedingFetch.count)\nIgnored conversations: \(ignoredConversationIDKeys.count)\nDecoded conversations: \(decodedConversations.count)",
            domain: .userSession,
            sender: self
        )

        if conversationsNeedingFetch.isEmpty,
           conversationsNeedingUpdate.isEmpty {
            if let existingConversations = user.conversations,
               !existingConversations.isEmpty,
               Set(existingConversations) == decodedConversations {
                return
            }

            return commitConversationsToMemory(decodedConversations)
        }

        guard !Task.isCancelled else { return }
        try await decodedConversations.merge(
            with: conversationsNeedingUpdate.map {
                @Dependency(\.clientSession.conversation.sync) var conversationSyncService: ConversationSyncService
                return try await conversationSyncService.synchronizeConversation($0)
            }
        )

        guard !conversationsNeedingFetch.isEmpty else {
            try validateRatio(
                decodedConversations,
                conversationIDs
            )

            return commitConversationsToMemory(decodedConversations)
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

        commitConversationsToMemory(decodedConversations)
    }

    /// Fetches messages for visible conversations on the
    /// current user whose messages are not yet in the session
    /// store.
    ///
    /// Conversation resolution populates conversation objects
    /// but does not always fetch their messages. This method
    /// fills that gap for conversations that were loaded from
    /// the archive or freshly fetched from the network.
    private func resolveMessagesOnCurrentUserConversations() async throws(Exception) {
        guard let conversations = currentUser?.conversations else { return }

        guard !Task.isCancelled else { return }
        let conversationsNeedingMessages = conversations
            .visibleForCurrentUser
            .map(\.filteringSystemMessages)
            .filter {
                !$0.messageIDs.isBangQualifiedEmpty &&
                    (
                        $0.messages == nil ||
                            $0.messages?.isEmpty == true ||
                            $0.messageIDs.count != $0.messages?.count
                    )
            }

        guard !Task.isCancelled,
              !conversationsNeedingMessages.isEmpty else { return }

        try await conversationsNeedingMessages.map {
            guard !Task.isCancelled else { return }
            try await $0.resolveMessages()
        }
    }

    /// Fetches users for visible conversations on the current
    /// user whose participants are not yet in the session
    /// store.
    private func resolveUsersOnCurrentUserConversations() async throws(Exception) {
        guard let user = currentUser,
              let conversations = user.conversations else { return }

        guard !Task.isCancelled else { return }
        try await conversations
            .visibleForCurrentUser
            .map {
                guard !Task.isCancelled else { return }
                try await $0.resolveUsers()
            }
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

    /// Resolves the current user and their conversations in
    /// response to an observed change.
    ///
    /// Only one update runs at a time. If a second call
    /// arrives while an update is in progress, it is queued
    /// and retried after the current update completes.
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
                try await resolveCurrentUser()
                Logger.log(
                    "Updated current user.",
                    domain: .userSession,
                    sender: self
                )

                do throws(Exception) {
                    try await resolveCurrentUserConversations()
                } catch {
                    Logger.log(
                        error,
                        domain: .userSession
                    )
                }

                do throws(Exception) {
                    try await resolveCurrentUser(
                        and: [
                            .messages,
                            .users,
                        ]
                    )
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
                    _ = try? await self.clientSession.storage.getCurrentUserDataUsage()
                }
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
