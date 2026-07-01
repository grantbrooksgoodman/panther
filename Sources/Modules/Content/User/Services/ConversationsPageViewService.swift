//
//  ConversationsPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable type_body_length file_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

@MainActor
final class ConversationsPageViewService {
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

        var next: ReloadType {
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
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    private(set) var didShowSecondsToLoadToast = false

    private var currentReloadType: ReloadType = .full

    // MARK: - View Lifecycle

    func viewAppeared() {
        didShowSecondsToLoadToast = false
        NavigationBar.setAppearance(.conversationsPageView)
        clientSession.user.startObservingCurrentUserChanges()

        Task.delayed(by: .milliseconds(500)) { @MainActor [weak self] in
            StatusBar.overrideStyle(.appAware)
            self?.fixSearchBarAppearance()
        }

        Task {
            @Dependency(\.commonServices.pushToken) var pushTokenService: PushTokenService
            do throws(Exception) {
                try await pushTokenService.updatePushTokensForCurrentUser()
            } catch {
                Logger.log(error)
            }
        }
    }

    func viewDisappeared() {
        StatusBar.overrideStyle(.appAware)
    }

    /// `.resolveReturned`
    func viewLoaded() {
        networking.database.clearTemporaryCaches()
        reloadIfNeeded()

        Task.delayed(by: .seconds(1)) { @MainActor in
            do throws(Exception) {
                try await showPromptsIfNeeded()
            } catch {
                Logger.log(error)
            }

            startSettingSearchBarAppearance()
        }

        enableOfflineModeSideEffects()
    }

    func traitCollectionChanged() {
        guard !chatPageState.isPresented else {
            return chatPageState.addEffectUponIsPresented(
                changedTo: false,
                id: .updateAppearance
            ) {
                Observables.traitCollectionChanged.trigger()
            }
        }

        guard navigation.state.userContent.sheet == nil else { return }

        Task { @MainActor in
            NavigationBar.setAppearance(.conversationsPageView)
            StatusBar.overrideStyle(.appAware)
            fixSearchBarAppearance()
        }
    }

    // MARK: - Reducer Action Handlers

    func deleteConversationsToolbarButtonTapped() {
        func populateValuesIfNeeded() async throws(Exception) {
            guard let currentUser = clientSession.user.currentUser,
                  currentUser.conversations == nil ||
                  currentUser.conversations?.isEmpty == true else { return }
            try await clientSession.user.resolveCurrentUserData()
        }

        Task { @MainActor in
            do throws(Exception) {
                try await populateValuesIfNeeded()
                DevModeAction
                    .AppActions
                    .DangerZone
                    .deleteConversationsAction
                    .perform()
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    /// `.pulledToRefresh`
    func reloadData() async throws(Exception) -> [Conversation] {
        try await reloadData(
            type: currentReloadType
        )
    }

    /// `.composeToolbarButtonTapped`
    func storageFullButtonTapped() {
        Task {
            await clientSession.storage.presentStorageWarningAlert()
        }
    }

    /// `.reloadDataReturned(.success)`
    /// `.updatedCurrentUser`
    /// `.viewAppeared`
    func updateConversationsList(
        with providedConversations: [Conversation]? = nil,
        state: inout ConversationsPageReducer.State
    ) {
        let conversations = (
            providedConversations ?? clientSession.user.currentUser?.conversations ?? []
        )
        .filteredAndSorted
        .map(\.injectingCachedUsers)

        guard !conversations.isEmpty else {
            // If the chat session holds a valid conversation that hasn't been
            // synced to conversationIDs yet, use it directly so the list
            // populates immediately without waiting for the server.
            if let currentConversation = clientSession.conversation.currentConversation,
               !currentConversation.isMock,
               currentConversation.isVisibleForCurrentUser {
                state.conversations = [
                    currentConversation.injectingCachedUsers,
                ].filteredAndSorted
            } else {
                state.conversations = []
            }

            resolveUnsyncedConversationIfNeeded()
            Observables.updateConversationsListSetToReliableDataSource.trigger()
            return
        }

        state.conversations = conversations
        Observables.updateConversationsListSetToReliableDataSource.trigger()
    }

    // MARK: - Auxiliary

    func showSecondsToLoadToastIfNeeded() {
        guard !didShowSecondsToLoadToast else { return }
        didShowSecondsToLoadToast = true

        let currentUser = clientSession.user.currentUser
        let numberOfConversations = currentUser?
            .conversations?
            .visibleForCurrentUser
            .count ?? currentUser?
            .conversationIDs?
            .count ?? 1

        let secondsToLoad = max(
            abs(Application.loadStartDate.seconds(from: .now)) - 1,
            0
        )
        let secondsPerConversation = String(
            format: "%.2f",
            Float(secondsToLoad) / Float(numberOfConversations)
        )

        let suffix = (Float(secondsPerConversation) ?? 0) <= 0.05 ? nil : " (\(secondsPerConversation)s/conversation)"

        @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
        let allMessages = (currentUser?.conversations ?? conversationArchive)?
            .visibleForCurrentUser
            .compactMap(\.messages)
            .flatMap(\.self) ?? []

        let uniqueMessages = allMessages.uniquedByID
        let audioMessageCount = uniqueMessages.filter(\.contentType.isAudio).count
        let mediaMessageCount = uniqueMessages.filter(\.contentType.isMedia).count
        let totalMessageCount = uniqueMessages.count
        let textMessageCount = totalMessageCount - (audioMessageCount + mediaMessageCount)

        let safeMessageCount: Double = totalMessageCount == 0 ? 1 : Double(totalMessageCount)
        let audioMessagePercent = (Double(audioMessageCount) / safeMessageCount).roundedString
        let mediaMessagePercent = (Double(mediaMessageCount) / safeMessageCount).roundedString
        let textMessagePercent = (Double(textMessageCount) / safeMessageCount).roundedString

        var addendum = ""
        if totalMessageCount > 0 {
            addendum = "\nUser has \(totalMessageCount) messages and \(numberOfConversations) conversations."
            addendum += "\n\(textMessagePercent)% text, \(audioMessagePercent)% audio, \(mediaMessagePercent)% media."
        }

        let seconds = "second\(secondsToLoad == 1 ? "" : "s")"
        Logger.log(
            "Loaded content in \(secondsToLoad) \(seconds)\(suffix ?? "").\(addendum)",
            domain: .conversation,
            sender: self
        )

        guard build.milestone != .generalRelease else { return }
        Toast.show(.init(
            message: "Loaded content in \(secondsToLoad) \(seconds)\(suffix ?? "").\(addendum)",
            perpetuation: .ephemeral(.seconds(10))
        ))
    }

    private func enableOfflineModeSideEffects() {
        func showOfflineModeToast() {
            Toast.show(.init(
                .capsule(style: .warning),
                message: Localized(.offlineMode).wrappedValue,
                perpetuation: .ephemeral(.seconds(10))
            ))
        }

        /// - NOTE: Fixes a bug in which an offline startup would fail to properly set the navigation bar appearance.
        func updateAppearance() {
            Logger.log(
                "Intercepted offline startup navigation bar appearance bug.",
                domain: .bugPrevention,
                sender: self
            )

            Task.delayed(by: .milliseconds(500)) { @MainActor in
                Observables.traitCollectionChanged.trigger()
            }
        }

        services.connectionStatus.addEffectUponConnectionChanged(id: .checkForUpdates) {
            guard self.build.isOnline else { return }
            Task {
                do throws(Exception) {
                    try await self
                        .services
                        .update
                        .promptToUpdateIfNeeded()
                } catch {
                    Logger.log(
                        error,
                        with: .toastInPrerelease
                    )
                }
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

    /// - NOTE: Fixes a bug in which upon the initial appearance of the view (in iOS 26 GM), the search bar background would not render properly.
    private func fixSearchBarAppearance() {
        guard UIApplication.isFullyV26Compatible else { return }
        var searchBarTextFieldBackgroundColor: UIColor {
            .init(
                hex: ThemeService.isDarkModeActive ? 0x1F1F1F : 0xF5F5F5
            )
        }

        uiApplication
            .presentedViews
            .filter {
                $0.descriptor == "UISearchBarTextField" &&
                    $0.backgroundColor != searchBarTextFieldBackgroundColor
            }
            .unique
            .forEach { $0.backgroundColor = searchBarTextFieldBackgroundColor }
    }

    private func markStale(conversation: Conversation) -> Conversation {
        var newConversationMessageIDs = conversation.messageIDs

        if let conversationMessages = conversation.messages,
           conversationMessages.count > 1 {
            newConversationMessageIDs = Array(
                conversationMessages[0 ... conversationMessages.count - 2]
            ).map(\.id)
        }

        return conversation
            .copying(
                id: .init(
                    key: conversation.id.key,
                    hash: .bangQualifiedEmpty
                )
            )
            .copying(messageIDs: newConversationMessageIDs)
    }

    private func reloadData(
        type: ReloadType
    ) async throws(Exception) -> [Conversation] {
        if let conversations = clientSession
            .user
            .currentUser?
            .conversations?
            .visibleForCurrentUser
            .sortedByLatestMessageSentDate,
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

            let staleConversations = Set(array.map {
                markStale(conversation: $0)
            })

            networking
                .conversationService
                .archive
                .addValues(staleConversations)
        }

        defer { currentReloadType = currentReloadType.next }

        try await clientSession.user.resolveCurrentUser()
        try await clientSession.user.resolveCurrentUserData()

        var randomBool: Bool {
            Int.random(in: 1 ... 1_000_000) % 3 == 0
        }

        guard !services.contact.hasContactsBesidesCurrentUser || randomBool else {
            return clientSession.user.currentUser?.conversations ?? []
        }

        do {
            try await services.contact.syncContactPairArchive()
        } catch {
            if !error.isEqual(toAny: [
                .mismatchedHashAndCallingCode,
                .notAuthorizedForContacts,
            ]) {
                throw error
            }
        }

        return clientSession.user.currentUser?.conversations ?? []
    }

    /// - NOTE: Fixes a bug in which the list of conversations would not be populated upon the view's first appearance.
    private func reloadIfNeeded() {
        guard let currentUser = clientSession.user.currentUser,
              currentUser.conversations == nil || currentUser.conversations?.isEmpty == true,
              (currentUser.conversationIDs?.count ?? 0) > 0 else { return }

        Logger.log(
            "Intercepted empty initial conversations list bug.",
            domain: .bugPrevention,
            sender: self
        )

        Observables.updatedCurrentUser.trigger()
    }

    /// Syncs the current user's `conversationIDs` with the server in the background.
    ///
    /// After a new conversation is created and the chat page is dismissed, the server
    /// may not yet have associated the conversation with the user. The caller populates
    /// the list immediately from local data; this method resolves the authoritative
    /// server state so that subsequent update cycles use fully resolved data.
    private func resolveUnsyncedConversationIfNeeded() {
        guard let currentConversation = clientSession.conversation.currentConversation,
              !currentConversation.isMock else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do throws(Exception) {
                try await clientSession.user.resolveCurrentUser()
                try await clientSession.user.resolveCurrentUserData()
            } catch {
                Logger.log(
                    error,
                    domain: .conversation
                )
            }

            // Don't re-trigger when the server still reports no conversations;
            // the Firebase observer will fire naturally once it catches up.
            guard !(clientSession.user.currentUser?.conversationIDs ?? []).isEmpty else { return }
            Observables.updatedCurrentUser.trigger()
        }
    }

    /// Evaluates several user-facing prompts in priority order.
    ///
    /// The flow is as follows:
    /// 1. If the user is approaching their data-usage limit, presents a storage warning alert.
    /// 2. Otherwise, if notification permission has not been determined, requests notification permission.
    /// 3. Otherwise, suggests inviting friends, if appropriate.
    /// 4. If no invite is suggested, prompts the user for an App Store review, if appropriate.
    ///
    /// After the flow completes, either via alert dismissal or no cases having been met,
    /// a `FeaturePermissionPageView` may be presented when one or more feature permission pages are eligible.
    /// Eligible pages are assembled in this order:
    /// - `.aiEnhancedTranslations` (only once per install; if disabled for the current user)
    /// - `.penPals` (only once per install; if the user is not a participant)
    ///
    /// If no pages are eligible, no sheet is presented.
    @MainActor
    private func showPromptsIfNeeded() async throws(Exception) {
        _ = try await clientSession.storage.getCurrentUserDataUsage()
        if clientSession.storage.isApproachingDataUsageLimit {
            await clientSession.storage.presentStorageWarningAlert()
        } else if await services.permission.notificationPermissionStatus == .unknown {
            _ = try await services.permission.requestPermission(for: .notifications)
        } else if await !(services.invite.suggestInvitationIfNeeded()) {
            services.review.promptToReview()
        }

        // swiftlint:disable:next identifier_name
        @Persistent(.presentedAIEnhancedTranslationPermissionPageAtStartup) var presentedAIEnhancedTranslationPermissionPageAtStartup: Bool?
        @Persistent(.presentedPenPalsPermissionPageAtStartup) var presentedPenPalsPermissionPageAtStartup: Bool?

        let presentedAIPage = presentedAIEnhancedTranslationPermissionPageAtStartup ?? false
        let presentedPenPalsPage = presentedPenPalsPermissionPageAtStartup ?? false

        var configurations = [FeaturePermissionPageView.Configuration]()
        if !presentedAIPage,
           clientSession.user.currentUser?.aiEnhancedTranslationsEnabled == false {
            configurations.append(.aiEnhancedTranslations)
            presentedAIEnhancedTranslationPermissionPageAtStartup = true
        }

        if !presentedPenPalsPage,
           clientSession.user.currentUser?.isPenPalsParticipant == false {
            configurations.append(.penPals)
            presentedPenPalsPermissionPageAtStartup = true
        }

        if !configurations.isEmpty {
            Application.dismissSheets()
            uiApplication.resignFirstResponders()
            Task.delayed(by: .milliseconds(350)) { @MainActor in
                RootSheets.present(
                    .featurePermissionPageView(configurations)
                )
            }
        }
    }

    private func startSettingSearchBarAppearance() {
        guard Application.isInPrevaricationMode,
              !UIApplication.isFullyV26Compatible else { return }

        var misconfiguredSearchFieldBackgroundViews: [UIView] {
            uiApplication
                .presentedViews
                .compactMap { $0 as? UISearchBar }
                .flatMap(\.traversedSubviews)
                .filter { $0.descriptor == "_UISearchBarSearchFieldBackgroundView" }
                .filter { $0.backgroundColor != .init(hex: 0xE7E7E9) }
        }

        if !chatPageState.isPresented,
           !uiApplication.isPresentingSheet {
            misconfiguredSearchFieldBackgroundViews.forEach { $0.backgroundColor = .init(hex: 0xE7E7E9) }
        }

        Task.delayed(by: .milliseconds(10)) { @MainActor [weak self] in
            self?.startSettingSearchBarAppearance()
        }
    }
}

extension Conversation: Validatable {
    var isWellFormed: Bool {
        guard !id.key.isBlank,
              !id.hash.isBlank else { return false }

        if isVisibleForCurrentUser {
            guard let messages,
                  !messages.isEmpty,
                  messages.filteringSystemMessages.count == messageIDs.count,
                  let users,
                  !users.isEmpty else { return false }
        }

        return true
    }
}

@MainActor
private extension Conversation {
    var injectingCachedUsers: Conversation {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        guard isVisibleForCurrentUser,
              (users?.count ?? 0) == 0 else { return self }

        let participantUserIDs = Set(
            participants.map(\.userID).filter { $0 != User.currentUserID }
        )

        let resolvedUsers = UserCache
            .knownUsers
            .filter { participantUserIDs.contains($0.id) }
            .uniquedByID

        guard participantUserIDs.isSubset(
            of: resolvedUsers.map(\.id)
        ) else { return self }

        sessionStore.upsertUsers(resolvedUsers)
        return self
    }
}

// swiftlint:enable type_body_length file_length
