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
import Networking

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
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    private var currentReloadType: ReloadType = .full

    // MARK: - Public

    public func viewAppeared() {
        NavigationBar.setAppearance(.appDefault)
        userSession.startObservingCurrentUserChanges()

        core.gcd.after(.milliseconds(500)) {
            StatusBar.overrideStyle(.appAware)
        }

        Task {
            if let exception = await services.pushToken.updatePushTokensForCurrentUser() {
                Logger.log(exception)
            }
        }
    }

    public func viewDisappeared() {
        StatusBar.overrideStyle(.appAware)
    }

    /// `.resolveReturned`
    public func viewLoaded(_ isConversationsListEmpty: Bool) {
        func showOfflineModeToast() {
            Toast.show(.init(
                .capsule(style: .warning),
                message: Localized(.offlineMode).wrappedValue,
                perpetuation: .ephemeral(.seconds(10))
            ))
        }

        /// - NOTE: Fixes a bug in which the list of conversations would not be populated upon the view's first appearance.
        func reloadIfNeeded() {
            guard isConversationsListEmpty,
                  (userSession.currentUser?.conversationIDs?.count) ?? 0 > 0 else { return }

            Logger.log(
                "Intercepted empty initial conversations list bug.",
                domain: .bugPrevention,
                metadata: [self, #file, #function, #line]
            )

            Observables.updatedCurrentUser.trigger()
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

        if build.milestone != .generalRelease {
            Toast.show(.init(
                message: "Loaded content in \(abs(Application.loadStartDate.seconds(from: .now))) seconds.",
                perpetuation: .ephemeral(.seconds(5))
            ))
        }

        networking.database.clearTemporaryCaches()
        reloadIfNeeded()

        Task.delayed(by: .seconds(1)) { @MainActor in
            defer {
                @Persistent(.presentedPenPalsPermissionPageAtStartup) var presentedPenPalsPermissionPageAtStartup: Bool?
                if !(presentedPenPalsPermissionPageAtStartup ?? false),
                   userSession.currentUser?.isPenPalsParticipant == false {
                    presentedPenPalsPermissionPageAtStartup = true
                    RootSheets.present(.penPalsPermissionPageView)
                }
            }

            guard await self.services.permission.notificationPermissionStatus == .unknown else {
                self.services.review.promptToReview()
                return
            }

            _ = await self.services.permission.requestPermission(for: .notifications)
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

            let resolveCurrentUserResult = await userSession.resolveCurrentUser()
            currentReloadType = currentReloadType.next

            switch resolveCurrentUserResult {
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

                if let exception = await services.contact.syncContactPairArchive(),
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

    public func traitCollectionChanged() {
        guard !chatPageState.isPresented else {
            return chatPageState.addEffectUponIsPresented(changedTo: false, id: .updateAppearance) { Observables.traitCollectionChanged.trigger() }
        }

        guard navigation.state.userContent.sheet == nil else { return }

        Task { @MainActor in
            NavigationBar.setAppearance(.appDefault)
            StatusBar.overrideStyle(.appAware)
        }
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
            reactionMetadata: conversation.reactionMetadata,
            users: conversation.users
        )

        networking.conversationService.archive.addValue(newConversation)
    }
}
