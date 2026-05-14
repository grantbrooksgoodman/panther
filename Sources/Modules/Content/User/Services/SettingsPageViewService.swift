//
//  SettingsPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Contacts
import Foundation
import SwiftUI

/* Proprietary */
import AlertKit
import AppSubsystem

@MainActor
final class SettingsPageViewService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case cnContactForCurrentUser
    }

    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.SettingsPageView
    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.clientSession.moderation) private var moderationSession: ModerationSessionService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.reportDelegate) private var reportDelegate: ReportDelegate
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard

    // MARK: - Properties

    var isMainPagePresented = true

    @Cached(CacheKey.cnContactForCurrentUser) private var cachedCNContactForCurrentUser: CNContact?

    // MARK: - Init

    nonisolated init() {}

    // MARK: - Reducer Action Handlers

    func aiEnhancedTranslationsSwitchToggled(on: Bool) {
        Task { @MainActor in
            guard on else {
                if let exception = await services
                    .aiEnhancedTranslation
                    .setDidGrantAIEnhancedTranslationPermission(false) {
                    Logger.log(
                        exception,
                        with: .toast
                    )
                }

                return
            }

            RootSheets.present(
                .featurePermissionPageView([.aiEnhancedTranslations])
            )
        }
    }

    func blockedUsersButtonTapped() {
        Task {
            guard let exception = await moderationSession.unblockUsers() else { return }
            Logger.log(exception, with: .toast)
        }
    }

    func changeThemeButtonTapped() {
        Task {
            var actions = [AKAction]()

            @MainActor
            func isCurrentTheme(_ theme: UITheme) -> Bool {
                theme.encodedHash == ThemeService.currentTheme.encodedHash
            }

            func themeName(_ theme: UITheme) -> String {
                RuntimeStorage.languageCode == "en" ? theme.name : (theme.nonEnglishName ?? theme.name)
            }

            actions = UITheme.allCases.filter { $0 != .default }.map { uiTheme in
                .init(
                    isCurrentTheme(uiTheme) ? "\(themeName(uiTheme)) (Applied)" : themeName(uiTheme),
                    isEnabled: !isCurrentTheme(uiTheme)
                ) {
                    Task { @MainActor in
                        ThemeService.setTheme(uiTheme)
                        guard ThemeService.currentTheme.style != uiTheme.style else { return }
                        self.notificationCenter.addObserver(
                            self,
                            name: .uiAlertControllerDismissed,
                            removeAfterFirstPost: true
                        ) { _ in
                            Task.delayed(by: .milliseconds(500)) { @MainActor in
                                Observables.traitCollectionChanged.trigger()
                            }
                        }
                    }
                }
            }

            await AKActionSheet(
                title: "Change Theme",
                actions: actions,
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions([]), .title])
        }
    }

    func clearCachesButtonTapped() {
        @MainActor
        func clearCaches() async {
            @Dependency(\.clientSession.user) var userSession: UserSessionService

            if let exception = userSession.stopObservingCurrentUserChanges() {
                Logger.log(
                    exception,
                    domain: .userSession
                )
            }

            services.analytics.logEvent(.clearCaches)
            Application.reset(preserveCurrentUserID: true)

            var actions = [
                AKAction(
                    "Exit",
                    style: .destructivePreferred,
                    effect: {
                        Task { @MainActor in
                            self.exitGracefully()
                        }
                    }
                ),
            ]

            if build.isDeveloperModeEnabled {
                let reloadAction = AKAction("Reload") {
                    Task { @MainActor in
                        self.navigation.navigate(to: .userContent(.sheet(.none)))
                        self.navigation.navigate(to: .root(.modal(.splash)))
                    }
                }

                actions.insert(reloadAction, at: 0)
            }

            await AKAlert(
                message: "Caches have been cleared. \(build.isDeveloperModeEnabled ? "" : "You must now restart the app.")",
                actions: actions
            ).present()
        }

        Task {
            let confirmed = await AKConfirmationAlert(
                title: "Clear Caches", // swiftlint:disable:next line_length
                message: "Are you sure you'd like to clear all caches?\n\nThis may fix some issues, but can also temporarily slow down the app while indexes rebuild.\(build.isDeveloperModeEnabled ? "" : "\n\nYou will need to restart the app for this to take effect.")",
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                confirmButtonStyle: .destructivePreferred
            ).present(translating: [.confirmButtonTitle, .message, .title])

            guard confirmed else { return }
            await clearCaches()
        }
    }

    func deleteAccountButtonTapped() {
        Task {
            @MainActor
            @Sendable
            func clearCachesAndExit() async {
                if let exception = await services.notification.setBadgeNumber(0, updateHostedValue: false) {
                    Logger.log(exception)
                }

                services.analytics.logEvent(.deleteAccount)
                Application.reset(
                    preserveCurrentUserID: false,
                    onCompletion: .exitGracefully
                )
            }

            let confirmed = await AKConfirmationAlert(
                title: "Delete Account", // swiftlint:disable:next line_length
                message: "Are you sure you'd like to delete your account? All user data will be deleted.\n\nIf you wish to continue using ⌘\(build.finalName)⌘, you will need to create a new account.\n\nAn app restart is required for this process to complete.",
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                confirmButtonStyle: .destructivePreferred
            ).present(translating: [.confirmButtonTitle, .message, .title])

            guard confirmed else { return }
            let deleteAccountAction: AKAction = .init("Delete Account", style: .destructivePreferred) {
                Task { @MainActor in
                    if let exception = await self.services.accountDeletion.deleteAccount() {
                        Logger.log(exception)
                    }

                    let exitAction: AKAction = .init("Exit", style: .destructivePreferred) {
                        Task { @MainActor in await clearCachesAndExit() }
                    }

                    await AKAlert(
                        message: "Your account has been deleted. You must now restart the app.",
                        actions: [exitAction]
                    ).present()
                }
            }

            await AKActionSheet(
                actions: [deleteAccountAction],
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions([])])
        }
    }

    func inviteFriendsButtonTapped() {
        Task {
            let shareToOtherAppAction: AKAction = .init("Share to Another App") {
                Task { @MainActor in
                    if let exception = await self.services.invite.presentInvitationPrompt() {
                        Logger.log(exception, with: .toast)
                    }
                }
            }

            let showQRCodeAction: AKAction = .init("Show QR Code") {
                Task { @MainActor in
                    self.navigation.navigate(to: .settings(.sheet(.inviteQRCode)))
                }
            }

            await AKActionSheet(
                title: "Invite Friends",
                actions: [shareToOtherAppAction, showQRCodeAction],
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions([]), .title])
        }
    }

    func leaveReviewButtonTapped() {
        guard let appShareLink = services.metadata.appShareLink?.absoluteString,
              let url = URL(string: "\(appShareLink)?action=write-review") else { return }
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }

    func messageRecipientConsentSwitchToggled(on: Bool) {
        Task {
            if let exception = await services.messageRecipientConsent.setMessageRecipientConsentRequired(on) {
                Logger.log(exception, with: .toast)
            }
        }
    }

    func penPalsParticipantSwitchToggled(on: Bool) {
        Task { @MainActor in
            guard on else {
                let confirmAction: AKAction = .init(
                    "Confirm",
                    style: .destructive
                ) {
                    Task { @MainActor in
                        if let exception = await self.services.penPals.setDidGrantPenPalsPermission(false) {
                            Logger.log(exception, with: .toastInPrerelease)
                        }
                    }
                }

                let cancelAction: AKAction = .init(
                    Localized(.cancel).wrappedValue,
                    style: .cancel
                ) {
                    Observables.didGrantPenPalsPermission.value = true
                }

                return await AKActionSheet(
                    title: "Stop Participating in ⌘PenPals⌘?", // swiftlint:disable:next line_length
                    message: "This will remove your account from the pool of available ⌘PenPals⌘ for others to connect with.\n\nUntil re-enabled, you will not be able to start conversations with new ⌘PenPals⌘.",
                    actions: [confirmAction, cancelAction]
                ).present(translating: [.actions([confirmAction]), .message, .title])
            }

            RootSheets.present(
                .featurePermissionPageView([.penPals])
            )
        }
    }

    /// `.longPressGestureRecognized`
    func promptToEnterPrereleaseMode() {
        Task {
            @Persistent(.buildMilestoneString) var buildMilestoneString: String?
            guard build.milestone == .generalRelease else {
                let confirmed = await AKConfirmationAlert(
                    title: "Exit Prerelease Mode",
                    message: "Are you sure you'd like to exit Prerelease Mode? An app restart is required for this to take effect.",
                    confirmButtonTitle: "Apply & Exit",
                    confirmButtonStyle: .destructivePreferred
                ).present(translating: [])

                guard confirmed else { return }
                buildMilestoneString = nil
                exit(0)
            }

            let input = await AKTextInputAlert(
                title: "Enter Prerelease Mode",
                message: "Enter the correct passphrase to continue.",
                attributes: .init(
                    isSecureTextEntry: true,
                    keyboardType: .numberPad,
                    placeholderText: "••••••"
                ),
                confirmButtonTitle: "Done"
            ).present(translating: [])

            guard let input else { return }
            guard input == build.expirationOverrideCode.components.reversed().joined() else {
                return await AKAlert(
                    title: "Enter Prerelease Mode",
                    message: "The passphrase entered was incorrect. Please try again.",
                    actions: [
                        .init("Try Again", style: .preferred) {
                            Task { @MainActor in
                                self.promptToEnterPrereleaseMode()
                            }
                        },
                        .cancelAction(title: "Cancel"),
                    ]
                ).present(translating: [])
            }

            buildMilestoneString = Build.Milestone.beta.rawValue

            let exitAction: AKAction = .init("Exit", style: .destructivePreferred) { exit(0) }
            await AKAlert(
                message: "Successfully entered Prerelease Mode. You must now restart the app.",
                actions: [exitAction]
            ).present(translating: [])
        }
    }

    func sendFeedbackButtonTapped() {
        Task {
            let reportBugAction: AKAction = .init("Report Bug") {
                Task { @MainActor in
                    self.reportDelegate.reportBug()
                }
            }

            await AKActionSheet(
                title: "File a Report",
                actions: [
                    .init(Localized(.sendFeedback).wrappedValue) {
                        Task { @MainActor in
                            self.reportDelegate.sendFeedback()
                        }
                    },
                    reportBugAction,
                ],
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [
                .actions([reportBugAction]),
                .title,
            ])
        }
    }

    func signOutButtonTapped() {
        Task { @MainActor in
            let signOutAction: AKAction = .init("Sign Out", style: .destructivePreferred) {
                Task { @MainActor in
                    if let exception = await self.services.notification.setBadgeNumber(
                        0,
                        updateHostedValue: false
                    ) {
                        Logger.log(exception)
                    }

                    defer {
                        Application.dismissSheets()
                        Application.reset()
                        self.services.analytics.logEvent(.logOut)

                        Task.delayed(by: .milliseconds(Floats.signOutNavigationDelayMilliseconds)) { @MainActor in
                            self.navigation.navigate(to: .onboarding(.stack([])))
                            self.navigation.navigate(to: .root(.modal(.onboarding)))
                        }
                    }

                    guard let currentUser = self.clientSession.user.currentUser else { return }

                    if let exception = self.clientSession.user.stopObservingCurrentUserChanges() {
                        Logger.log(exception)
                    }

                    if let exception = await currentUser.removeCurrentPushToken() {
                        Logger.log(exception)
                    }

                    if let exception = await currentUser.updateLastSignedInDate(
                        to: .init(timeIntervalSince1970: 0)
                    ) {
                        Logger.log(exception)
                    }
                }
            }

            let sourceItemString = RuntimeStorage.languageCode == "en" ? "Sign out" : "Log out"
            await AKActionSheet(
                actions: [signOutAction],
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                sourceItem: .custom(.string(sourceItemString.localized))
            ).present(translating: [.actions([])])
        }
    }

    /// `.longPressGestureRecognized`
    func setClipboardWithHapticFeedback(_ string: String) {
        uiPasteboard.string = string
        services.haptics.generateFeedback(.heavy)
    }

    // MARK: - Developer Mode List Items

    /// `.viewAppeared`
    func developerModeListItems() -> [ListRowView.Configuration]? {
        func overrideLanguageCodeButtonTapped() {
            guard RuntimeStorage.retrieve(.overriddenLanguageCode) == nil else {
                guard let currentUser = clientSession.user.currentUser else { return }
                let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()

                alertKitConfig.overrideTargetLanguageCode(currentUser.languageCode)
                RuntimeStorage.remove(.overriddenLanguageCode)
                core.hud.showSuccess(text: "Set to \(languageName)")
                Application.dismissSheets()
                return
            }

            alertKitConfig.overrideTargetLanguageCode("en")
            RuntimeStorage.store("en", as: .overriddenLanguageCode)
            core.hud.showSuccess(text: "Set to English")
            Application.dismissSheets()
        }

        typealias Colors = AppConstants.Colors.SettingsPageView
        guard build.milestone != .generalRelease else { return nil }
        var items = [ListRowView.Configuration]()

        if build.isDeveloperModeEnabled,
           let currentUser = clientSession.user.currentUser,
           currentUser.languageCode != "en" {
            let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()
            let restoreLanguageCodeString = "\(Strings.restoreLanguageCodeButtonTextPrefix) \(languageName)"
            let overrideOrRestore = RuntimeStorage.retrieve(.overriddenLanguageCode) == nil ? Strings.overrideLanguageCodeButtonText : restoreLanguageCodeString

            items.append(
                .init(
                    .button(action: overrideLanguageCodeButtonTapped),
                    innerText: overrideOrRestore,
                    imageView: {
                        SquareIconView.image(
                            .init(
                                backgroundColor: Colors.overrideLanguageCodeButtonImageBackground,
                                overlay: .symbol(name: Strings.overrideLanguageCodeButtonImageSystemName)
                            )
                        ).swiftUIImage
                    }
                )
            )
        }

        if !build.isDeveloperModeEnabled {
            items.append(
                .init(
                    .button { DevModeService.promptToToggle() },
                    innerText: Strings.toggleDeveloperModeButtonText,
                    imageView: {
                        SquareIconView.image(
                            .init(
                                backgroundColor: Colors.toggleDeveloperModeButtonImageBackground,
                                overlay: .symbol(
                                    name: Strings.toggleDeveloperModeButtonImageSystemName,
                                    framePercentOfTotalSize: Floats.toggleDeveloperModeButtonOverlayFramePercentOfTotalSize,
                                    weight: .bold
                                )
                            )
                        ).swiftUIImage
                    }
                )
            )
        }

        return items
    }

    // MARK: - Fetch CNContact for Current User

    /// `.viewAppeared`
    func fetchCNContactForCurrentUser() async -> Callback<CNContact, Exception> {
        if let cachedCNContactForCurrentUser {
            return .success(cachedCNContactForCurrentUser)
        }

        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            ))
        }

        let firstCNContactResult = await services.contact.firstCNContact(for: currentUser.phoneNumber)

        switch firstCNContactResult {
        case let .success(cnContact):
            cachedCNContactForCurrentUser = cnContact
            return .success(cnContact)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Get Current User Data Usage

    /// `.viewAppeared`
    func getCurrentUserDataUsage() async -> Callback<Int, Exception> {
        await clientSession.storage.getCurrentUserDataUsage()
    }

    // MARK: - Clear Cache

    func clearCache() {
        cachedCNContactForCurrentUser = nil
    }

    // MARK: - Auxiliary

    private func exitGracefully() {
        Task { @MainActor in
            Application.dismissSheets()

            StatusBar.setIsHidden(true)
            core.ui.addOverlay(activityIndicator: .largeWhite)

            navigation.navigate(to: .root(.modal(.splash)))
            Task.delayed(by: .seconds(1)) { @MainActor in
                core.utils.exitGracefully()
            }
        }
    }
}

// swiftlint:enable file_length type_body_length
