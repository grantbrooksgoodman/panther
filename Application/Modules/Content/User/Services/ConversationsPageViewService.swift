//
//  ConversationsPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public final class ConversationsPageViewService {
    // MARK: - Types

    private enum ReloadType: String {
        /* MARK: Cases */

        /// Force update last 1/3 of conversations.
        case full

        /// No force updating.
        case minimal

        /// Force update last conversation.
        case partial

        /* MARK: Properties */

        public var next: ReloadType {
            switch self {
            case .full: .partial
            case .minimal: .full
            case .partial: .minimal
            }
        }
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    private var currentReloadType: ReloadType = .full

    // MARK: - Public

    public func viewAppeared() {
        userSession.startObservingCurrentUserChanges()

        Task {
            if let exception = await userSession.updatePushTokens() {
                Logger.log(exception)
            }
        }
    }

    /// `.resolveReturned(.success(_))`
    public func viewLoaded() {
        func showOfflineModeToast() {
            Observables.rootViewToast.value = .init(
                .capsule(style: .warning),
                message: Localized(.offlineMode).wrappedValue,
                perpetuation: .ephemeral(.seconds(10))
            )
        }

        /// - NOTE: Fixes a bug in which an offline startup would fail to properly set the navigation bar appearance.
        func updateAppearance() {
            Logger.log(
                "Intercepted offline startup navigation bar appearance bug.",
                domain: .bugPrevention,
                metadata: [self, #file, #function, #line]
            )

            core.gcd.after(.milliseconds(500)) {
                Observables.traitCollectionChanged.trigger()
            }
        }

        networking.database.clearTemporaryCaches()

        core.gcd.after(.seconds(1)) {
            Task { @MainActor in
                guard await self.services.permission.notificationPermissionStatus == .unknown else {
                    self.services.review.promptToReview()
                    return
                }

                _ = await self.services.permission.requestPermission(for: .notifications)
            }
        }

        services.connectionStatus.addEffectUponConnectionChanged(id: .showOfflineModeToast) {
            guard !self.build.isOnline else { return }
            showOfflineModeToast()
        }

        guard !build.isOnline else { return }
        updateAppearance()
        showOfflineModeToast()
    }

    /// `.pulledToRefresh`
    public func reloadData() async -> Callback<[Conversation], Exception> {
        func reloadData(type: ReloadType) async -> Callback<[Conversation], Exception> {
            if let conversations = userSession.currentUser?.conversations?.visibleForCurrentUser.sortedByLatestMessageSentDate,
               let firstConversation = conversations.first,
               type == .full || type == .partial {
                var array = [firstConversation]
                if type == .full {
                    if conversations.count > 5 {
                        array = Array(conversations[0 ... conversations.count / 3])
                    } else {
                        array = conversations
                    }
                }

                array.forEach { markStale(conversation: $0) }
            }

            let setCurrentUserResult = await userSession.setCurrentUser()
            currentReloadType = currentReloadType.next

            switch setCurrentUserResult {
            case let .success(user):
                if let exception = await user.setConversations() {
                    return .failure(exception)
                }

                if let exception = await user.conversations?.visibleForCurrentUser.setUsers() {
                    return .failure(exception)
                }

                @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
                var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 3 == 0 }
                guard (contactPairArchive ?? []).isEmpty || randomBool else { return .success(user.conversations ?? []) }

                if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: true),
                   !exception.isEqual(toAny: [.mismatchedHashAndCallingCode, .notAuthorizedForContacts]) {
                    return .failure(exception)
                }

                return .success(user.conversations ?? [])

            case let .failure(exception):
                return .failure(exception)
            }
        }

        return await reloadData(type: currentReloadType)
    }

    // MARK: - Auxiliary

    private func markStale(conversation: Conversation) {
        var newConversationMessageIDs = conversation.messageIDs
        var newConversationMessages = conversation.messages

        if let conversationMessages = conversation.messages,
           conversationMessages.count > 1 {
            newConversationMessages = .init(conversationMessages[0 ... conversationMessages.count - 2])
            newConversationMessageIDs = (newConversationMessages ?? []).map(\.id)
        }

        let newConversation: Conversation = .init(
            .init(key: conversation.id.key, hash: .bangQualifiedEmpty),
            messageIDs: newConversationMessageIDs,
            messages: newConversationMessages,
            metadata: conversation.metadata,
            participants: conversation.participants,
            users: conversation.users
        )

        networking.services.conversation.archive.addValue(newConversation)
    }
}
