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

    private enum TaskID: String {
        case showSecondsToLoadToast
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
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.userStorageService) private var userStorageService: UserStorageService

    // MARK: - Properties

    private var currentReloadType: ReloadType = .full
    private var didShowSecondsToLoadToast = false

    // MARK: - View Lifecycle

    func viewAppeared() {
        didShowSecondsToLoadToast = false
        NavigationBar.setAppearance(.conversationsPageView)
        clientSession.entity.user.startObservingCurrentUserChanges()

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
        Task { @MainActor in
            do throws(Exception) {
                try await clientSession.entity.user.resolveCurrentUser(
                    and: [.conversations]
                )

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
    func reloadData() async throws(Exception) {
        try await reloadData(type: currentReloadType)
    }

    /// `.composeToolbarButtonTapped`
    func storageFullButtonTapped() {
        Task {
            await userStorageService.presentStorageWarningAlert()
        }
    }

    // MARK: - Auxiliary

    func showSecondsToLoadToastIfNeeded() {
        guard !didShowSecondsToLoadToast else { return }
        didShowSecondsToLoadToast = true

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.showSecondsToLoadToast.rawValue)",
            delay: .seconds(1)
        ) { @MainActor [weak self] in
            guard let self else { return }

            let currentUser = clientSession.entity.user.currentUser
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

            let allMessages = (currentUser?.conversations ?? Array(clientSession.store.conversations.values))
                .visibleForCurrentUser
                .compactMap(\.messages)
                .flatMap(\.self)

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

    private func reloadData(
        type: ReloadType
    ) async throws(Exception) {
        if let conversations = clientSession
            .entity
            .user
            .currentUser?
            .conversations?
            .visibleForCurrentUser
            .sortedByLatestMessageSentDate,
            let firstConversation = conversations.first,
            type == .full || type == .partial {
            var conversationsToReload = [firstConversation]
            if type == .full {
                if conversations.count > 5 {
                    conversationsToReload = Array(conversations[
                        0 ... conversations.count / 3
                    ])
                } else {
                    conversationsToReload = conversations
                }
            }

            conversationsToReload.forEach { $0.markStaleLocally() }
        }

        defer { currentReloadType = currentReloadType.next }
        try await clientSession.entity.user.resolveCurrentUser(
            and: .allDataTypes
        )

        @Persistent(.lastContactSyncDate) var lastContactSyncDate: Date?
        let shouldSync: Bool = if !services.contact.hasContactsBesidesCurrentUser {
            true
        } else if let lastContactSyncDate {
            abs(lastContactSyncDate.timeIntervalSinceNow) >= Double(
                AppConstants.CGFloats.ConversationsPageView.contactSyncIntervalSeconds
            )
        } else {
            true
        }

        guard shouldSync else { return }
        do {
            try await services.contact.syncContactPairArchive()
            lastContactSyncDate = .now
        } catch {
            if !error.isEqual(toAny: [
                .mismatchedHashAndCallingCode,
                .notAuthorizedForContacts,
            ]) {
                throw error
            }
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
    private func showPromptsIfNeeded() async {
        do throws(Exception) {
            _ = try await userStorageService.getCurrentUserDataUsage()
            if userStorageService.isApproachingDataUsageLimit {
                await userStorageService.presentStorageWarningAlert()
            } else if await services.permission.notificationPermissionStatus == .unknown {
                _ = try await services.permission.requestPermission(for: .notifications)
            } else if await !(services.invite.suggestInvitationIfNeeded()) {
                services.review.promptToReview()
            }
        } catch {
            Logger.log(error)
        }

        // swiftlint:disable:next identifier_name
        @Persistent(.presentedAIEnhancedTranslationPermissionPageAtStartup) var presentedAIEnhancedTranslationPermissionPageAtStartup: Bool?
        @Persistent(.presentedPenPalsPermissionPageAtStartup) var presentedPenPalsPermissionPageAtStartup: Bool?

        let presentedAIPage = presentedAIEnhancedTranslationPermissionPageAtStartup ?? false
        let presentedPenPalsPage = presentedPenPalsPermissionPageAtStartup ?? false

        var configurations = [FeaturePermissionPageView.Configuration]()
        if !presentedAIPage,
           clientSession.entity.user.currentUser?.aiEnhancedTranslationsEnabled == false {
            configurations.append(.aiEnhancedTranslations)
            presentedAIEnhancedTranslationPermissionPageAtStartup = true
        }

        if !presentedPenPalsPage,
           clientSession.entity.user.currentUser?.isPenPalsParticipant == false {
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

                uiApplication.resignFirstResponders(
                    repeatingFor: .seconds(1)
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

// swiftlint:enable type_body_length file_length
