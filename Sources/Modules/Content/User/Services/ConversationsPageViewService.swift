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

final class ConversationsPageViewService {
    // MARK: - Types

    fileprivate struct ConversationSource {
        /* MARK: Properties */

        let conversations: [Conversation]
        let name: String

        /* MARK: Init */

        init(
            _ name: String,
            conversations: [Conversation]
        ) {
            self.name = name
            self.conversations = conversations
        }
    }

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
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    private var currentReloadType: ReloadType = .full

    // MARK: - View Lifecycle

    func viewAppeared() {
        NavigationBar.setAppearance(.conversationsPageView)
        clientSession.user.startObservingCurrentUserChanges()

        core.gcd.after(.milliseconds(500)) {
            StatusBar.overrideStyle(.appAware)
            self.fixSearchBarAppearance()
        }

        Task {
            if let exception = await services.pushToken.updatePushTokensForCurrentUser() {
                Logger.log(exception)
            }
        }
    }

    func viewDisappeared() {
        StatusBar.overrideStyle(.appAware)
    }

    /// `.resolveReturned`
    func viewLoaded() {
        showSecondsToLoadToastIfNeeded()
        networking.database.clearTemporaryCaches()
        reloadIfNeeded()

        Task.delayed(by: .seconds(1)) { @MainActor in
            await showPromptsIfNeeded()
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
        func populateValuesIfNeeded() async -> Exception? {
            guard let currentUser = clientSession.user.currentUser,
                  currentUser.conversations == nil ||
                  currentUser.conversations?.isEmpty == true else { return nil }
            return await currentUser.setConversations()
        }

        Task { @MainActor in
            if let exception = await populateValuesIfNeeded() {
                Logger.log(
                    exception,
                    with: .toast
                )
            } else {
                DevModeAction
                    .AppActions
                    .DangerZone
                    .deleteConversationsAction
                    .perform()
            }
        }
    }

    /// `.pulledToRefresh`
    func reloadData() async -> Callback<[Conversation], Exception> {
        func reloadData(type: ReloadType) async -> Callback<[Conversation], Exception> {
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

                array.forEach { markStale(conversation: $0) }
            }

            let resolveCurrentUserResult = await clientSession.user.resolveCurrentUser()
            currentReloadType = currentReloadType.next

            switch resolveCurrentUserResult {
            case let .success(user):
                if let exception = await user.setConversations() {
                    return .failure(exception)
                }

                if let exception = await user.conversations?.visibleForCurrentUser.setUsers() {
                    return .failure(exception)
                }

                var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 3 == 0 }
                guard !services.contact.hasContactsBesidesCurrentUser || randomBool else {
                    return .success(user.conversations ?? [])
                }

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
        @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
        let currentStateConversations = state.conversations
        let currentUserConversations = clientSession.user.currentUser?.conversations
        let currentUserConversationHashes = Set(
            clientSession
                .user
                .currentUser?
                .conversationIDs?
                .compactMap(\.hash) ?? []
        )

        guard !currentUserConversationHashes.isEmpty else { return }
        let dataSources: [ConversationSource] = [
            ConversationSource(
                "provided conversations",
                conversations: providedConversations ?? []
            ),
            ConversationSource(
                "current user conversations",
                conversations: currentUserConversations ?? []
            ),
            ConversationSource(
                "current state conversations",
                conversations: currentStateConversations
            ),
            ConversationSource(
                "conversation archive",
                conversations: conversationArchive ?? []
            ),
        ]
        .map {
            .init(
                $0.name,
                conversations: $0.conversations.filteredAndSorted.map(\.injectingCachedUsers)
            )
        }
        .filter { !$0.conversations.isEmpty }

        guard let bestCandidate = dataSources.bestAligned(
            with: currentUserConversationHashes,
            andMatchingPredicate: \.isWellFormed
        ) else {
            return Logger.log(
                .init(
                    "No conversation data source was well-formed.",
                    metadata: .init(sender: self),
                ),
                domain: .conversation,
                with: .toastInPrerelease
            )
        }

        guard build.milestone != .generalRelease else {
            return state.conversations = bestCandidate.conversations
        }

        if bestCandidate.name != "current user conversations",
           bestCandidate.name != "provided conversations" {
            Logger.log(
                "⚠️ Best candidate for list update was \(bestCandidate.name).",
                domain: .conversation,
                sender: self
            )
        } else {
            Logger.log(
                "✅ Set to reliable data source.",
                domain: .conversation,
                sender: self
            )
        }

        state.conversations = bestCandidate.conversations
    }

    // MARK: - Auxiliary

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

            core.gcd.after(.milliseconds(500)) {
                Observables.traitCollectionChanged.trigger()
            }
        }

        services.connectionStatus.addEffectUponConnectionChanged(id: .checkForUpdates) {
            guard self.build.isOnline else { return }
            Task {
                if let exception = await self.services.update.promptToUpdateIfNeeded() {
                    Logger.log(exception, with: .toastInPrerelease)
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
            activities: conversation.activities,
            messageIDs: newConversationMessageIDs,
            messages: newConversationMessages,
            metadata: conversation.metadata,
            participants: conversation.participants,
            reactionMetadata: conversation.reactionMetadata,
            users: conversation.users
        )

        networking.conversationService.archive.addValue(newConversation)
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
    private func showPromptsIfNeeded() async {
        _ = await clientSession.storage.getCurrentUserDataUsage()
        if clientSession.storage.isApproachingDataUsageLimit {
            await clientSession.storage.presentStorageWarningAlert()
        } else if await services.permission.notificationPermissionStatus == .unknown {
            _ = await services.permission.requestPermission(for: .notifications)
        } else if !(await services.invite.suggestInvitationIfNeeded()) {
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

    private func showSecondsToLoadToastIfNeeded() {
        let currentUser = clientSession.user.currentUser
        let numberOfConversations = currentUser?
            .conversations?
            .visibleForCurrentUser
            .count ?? currentUser?
            .conversationIDs?
            .count ?? 1

        let secondsToLoad = abs(Application.loadStartDate.seconds(from: .now))
        let secondsPerConversation = String(
            format: "%.2f",
            Float(secondsToLoad) / Float(numberOfConversations)
        )

        let suffix = (Float(secondsPerConversation) ?? 0) <= 0.05 ? nil : " (\(secondsPerConversation)s/conversation)"

        let allMessages = currentUser?
            .conversations?
            .visibleForCurrentUser
            .compactMap(\.messages)
            .flatMap(\.self) ?? []

        let audioMessageCount = allMessages.filter(\.contentType.isAudio).uniquedByID.count
        let mediaMessageCount = allMessages.filter(\.contentType.isMedia).uniquedByID.count
        let totalMessageCount = allMessages.uniquedByID.count
        let textMessageCount = totalMessageCount - (audioMessageCount + mediaMessageCount)

        let safeMessageCount: Double = totalMessageCount == 0 ? 1 : Double(totalMessageCount)
        let audioMessagePercent = (Double(audioMessageCount) / safeMessageCount).roundedString
        let mediaMessagePercent = (Double(mediaMessageCount) / safeMessageCount).roundedString
        let textMessagePercent = (Double(textMessageCount) / safeMessageCount).roundedString

        var addendum = ""
        if totalMessageCount > 0 {
            addendum = "\nUser has \(totalMessageCount) total messages."
            addendum += "\n\(textMessagePercent)% text, \(audioMessagePercent)% audio, \(mediaMessagePercent)% media."
        }

        Logger.log(
            "Loaded content in \(secondsToLoad) seconds\(suffix ?? "").\(addendum)",
            domain: .conversation,
            sender: self
        )

        guard build.milestone != .generalRelease else { return }
        Toast.show(.init(
            message: "Loaded content in \(secondsToLoad) seconds\(suffix ?? "").\(addendum)",
            perpetuation: .ephemeral(.seconds(10))
        ))
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

        core.gcd.after(.milliseconds(10)) { self.startSettingSearchBarAppearance() }
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

private extension Array where Element == ConversationsPageViewService.ConversationSource {
    func bestAligned(
        with canonicalHashes: Set<String>,
        andMatchingPredicate predicate: (Conversation) -> Bool
    ) -> ConversationsPageViewService.ConversationSource? {
        func score(_ source: ConversationsPageViewService.ConversationSource) -> (Int, Int) {
            let sourceHashes = Set(source.conversations.map(\.id.hash))

            let intersectingHashes = sourceHashes.intersection(canonicalHashes).count
            let extraHashes = sourceHashes.subtracting(canonicalHashes).count
            let missingHashes = canonicalHashes.subtracting(sourceHashes).count

            let countMatchingPredicate = source
                .conversations
                .lazy
                .filter(predicate)
                .count

            let alignmentScore = (intersectingHashes * 10) -
                (extraHashes * 50) -
                (missingHashes * 10)

            return (alignmentScore, countMatchingPredicate)
        }

        guard let first else { return nil }
        var bestCandidate = first
        var bestScore = score(first)

        defer { Logger.closeStream(domain: .conversation) }
        Logger.openStream(
            message: "Alignment score for \(first.name): \(bestScore.0)/\(bestScore.1)",
            domain: .conversation,
            sender: self
        )

        for dataSource in dropFirst() {
            let alignmentScore = score(dataSource)
            Logger.logToStream(
                "Alignment score for \(dataSource.name): \(alignmentScore.0)/\(alignmentScore.1)",
                domain: .conversation,
                line: #line
            )

            guard alignmentScore > bestScore else { continue }
            bestScore = alignmentScore
            bestCandidate = dataSource
        }

        return bestCandidate
    }
}

private extension Conversation {
    var injectingCachedUsers: Conversation {
        guard isVisibleForCurrentUser,
              (users?.count ?? 0) == 0 else { return self }

        let participantUserIDs = participants.map(\.userID).filter { $0 != User.currentUserID }
        let resolvedUsers = UserCache
            .knownUsers
            .filter { participantUserIDs.contains($0.id) }
            .uniquedByID

        guard resolvedUsers.map(\.id).containsAllStrings(
            in: participantUserIDs
        ) else { return self }

        return .init(
            id,
            activities: activities,
            messageIDs: messageIDs,
            messages: messages,
            metadata: metadata,
            participants: participants,
            reactionMetadata: reactionMetadata,
            users: resolvedUsers
        )
    }
}

// swiftlint:enable type_body_length file_length
