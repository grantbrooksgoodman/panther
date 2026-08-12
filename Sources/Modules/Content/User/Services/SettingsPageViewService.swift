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

/// The service that handles the settings page's user interactions.
///
/// Use ``SettingsPageViewService`` to respond to the settings page's controls – feature
/// switches, account actions, and support options – most of which confirm through alerts
/// before taking effect.
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
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.dataUsageService) private var dataUsageService: DataUsageService
    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.reportDelegate) private var reportDelegate: ReportDelegate
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard

    // MARK: - Properties

    /// A Boolean value that indicates whether the main settings page is presented.
    var isMainPagePresented = true

    @Cached(CacheKey.cnContactForCurrentUser) private var cachedCNContactForCurrentUser: CNContact?
    @SharedEvent(\.traitCollectionChanged) private var traitCollectionChanged

    // MARK: - Init

    /// Creates a settings page view service.
    nonisolated init() {}

    // MARK: - Reducer Action Handlers

    /// Responds to the AI-enhanced translation switch changing.
    ///
    /// Turning the switch off revokes the permission, surfacing any error as a toast; turning
    /// it on presents the AI-enhanced translation feature permission page.
    ///
    /// - Parameter on: The switch's new value.
    func aiEnhancedTranslationsSwitchToggled(on: Bool) {
        Task { @MainActor in
            guard on else {
                do throws(Exception) {
                    return try await services
                        .aiEnhancedTranslation
                        .setDidGrantAIEnhancedTranslationPermission(false)
                } catch {
                    return Logger.log(
                        error,
                        with: .toast
                    )
                }
            }

            RootSheets.present(
                .featurePermissionPageView([.aiEnhancedTranslations])
            )
        }
    }

    /// Begins the unblock users flow, surfacing any error as a toast.
    func blockedUsersButtonTapped() {
        Task {
            do throws(Exception) {
                try await entitySession.moderation.unblockUsers()
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    /// Presents an action sheet for choosing the app's theme.
    ///
    /// The applied theme is marked and disabled. Choosing a theme with a different interface
    /// style refreshes the app's appearance once the sheet dismisses.
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
                                self.traitCollectionChanged.send()
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

    /// Asks the user to confirm clearing all caches, applying it if they accept.
    ///
    /// Clearing resets the app – preserving the current user's identifier – and logs an
    /// analytics event. The app must then restart; in developer mode, an in-place reload is
    /// offered instead.
    func clearCachesButtonTapped() {
        @MainActor
        func clearCaches() async {
            entitySession.user.stopObservingCurrentUserChanges()
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

    /// Asks the user to confirm account deletion – twice – before deleting their account.
    ///
    /// After deletion, the badge number clears, an analytics event logs, and the app resets
    /// and exits.
    func deleteAccountButtonTapped() {
        Task {
            @MainActor
            @Sendable
            func clearCachesAndExit() async {
                do throws(Exception) {
                    try await services
                        .notification
                        .setBadgeNumber(
                            0,
                            updateHostedValue: false
                        )
                } catch {
                    Logger.log(error)
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
                    do throws(Exception) {
                        try await self.services.accountDeletion.deleteAccount()
                    } catch {
                        Logger.log(error)
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

    /// Presents an action sheet for inviting friends, offering to share the invitation to
    /// another app or to show the invite QR code.
    func inviteFriendsButtonTapped() {
        Task {
            let shareToOtherAppAction: AKAction = .init("Share to Another App") {
                Task { @MainActor in
                    do throws(Exception) {
                        try await self.services.invite.presentInvitationPrompt()
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
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

    /// Opens the App Store's write-review page for the app.
    ///
    /// If the app share link has not been resolved, this method does nothing.
    func leaveReviewButtonTapped() {
        guard let appShareLink = services.metadata.appShareLink?.absoluteString,
              let url = URL(string: "\(appShareLink)?action=write-review") else { return }
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }

    /// Records whether the current user requires message recipient consent, surfacing any
    /// error as a toast.
    ///
    /// - Parameter on: The switch's new value.
    func messageRecipientConsentSwitchToggled(on: Bool) {
        Task {
            do throws(Exception) {
                try await services
                    .messageRecipientConsent
                    .setMessageRecipientConsentRequired(on)
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    /// Responds to the PenPals participation switch changing.
    ///
    /// Turning the switch off asks for confirmation before revoking participation – canceling
    /// restores the switch; turning it on presents the PenPals feature permission page.
    ///
    /// - Parameter on: The switch's new value.
    func penPalsParticipantSwitchToggled(on: Bool) {
        Task { @MainActor in
            guard on else {
                let confirmAction: AKAction = .init(
                    "Confirm",
                    style: .destructive
                ) {
                    Task { @MainActor in
                        do throws(Exception) {
                            try await self
                                .services
                                .penPals
                                .setDidGrantPenPalsPermission(false)
                        } catch {
                            Logger.log(
                                error,
                                with: .toastInPrerelease
                            )
                        }
                    }
                }

                let cancelAction: AKAction = .init(
                    Localized(.cancel).wrappedValue,
                    style: .cancel
                ) {
                    SharedState(\.didGrantPenPalsPermission).wrappedValue = true
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

    /// Toggles prerelease mode after verification.
    ///
    /// On general-release builds, entering the correct passphrase switches the build
    /// milestone to beta; on prerelease builds, confirmation clears the override. Either
    /// change exits the app, which must restart for the change to take effect.
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

    /// Presents an action sheet for filing a report, offering to send feedback or report a
    /// bug.
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

    /// Asks the user to confirm signing out, applying it if they accept.
    ///
    /// Signing out clears the badge number, removes the device's push token from the user's
    /// record, resets the app, logs an analytics event, and returns to onboarding.
    func signOutButtonTapped() {
        Task { @MainActor in
            let signOutAction: AKAction = .init("Sign Out", style: .destructivePreferred) {
                Task { @MainActor in
                    do throws(Exception) {
                        try await self
                            .services
                            .notification
                            .setBadgeNumber(
                                0,
                                updateHostedValue: false
                            )
                    } catch {
                        Logger.log(error)
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

                    guard let currentUser = self.entitySession.user.currentUser else { return }

                    do throws(Exception) {
                        self
                            .entitySession
                            .user
                            .stopObservingCurrentUserChanges()

                        try await currentUser.removeCurrentPushToken()
                    } catch {
                        Logger.log(error)
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

    /// Copies the given string to the pasteboard, playing heavy haptic feedback.
    ///
    /// - Parameter string: The string to copy.
    func setClipboardWithHapticFeedback(_ string: String) {
        uiPasteboard.string = string
        services.haptics.generateFeedback(.heavy)
    }

    // MARK: - Developer Mode List Items

    /// Returns the developer mode list rows for the settings page.
    ///
    /// The rows offer toggling developer mode and, in developer mode – for users whose
    /// language is not English – overriding the app's language code to English.
    ///
    /// - Returns: The list row configurations; otherwise, `nil` on general-release builds.
    func developerModeListItems() -> [ListRowView.Configuration]? {
        func overrideLanguageCodeButtonTapped() {
            guard RuntimeStorage.retrieve(.overriddenLanguageCode) == nil else {
                guard let currentUser = entitySession.user.currentUser else { return }
                let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()

                alertKitConfig.overrideTargetLanguageCode(currentUser.languageCode)
                RuntimeStorage.remove(.overriddenLanguageCode)
                core.hud.showSuccess(text: "Set to \(languageName)")
                return Application.dismissSheets()
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
           let currentUser = entitySession.user.currentUser,
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

    /// Returns the device contact matching the current user's phone number.
    ///
    /// Results are cached in memory.
    ///
    /// - Returns: The matching Contacts framework contact.
    ///
    /// - Throws: An `Exception` if the current user has not been set, or if no matching
    ///   contact can be resolved.
    func fetchCNContactForCurrentUser() async throws(Exception) -> CNContact {
        if let cachedCNContactForCurrentUser {
            return cachedCNContactForCurrentUser
        }

        guard let currentUser = entitySession.user.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        let cnContact = try await services.contact.firstCNContact(
            for: currentUser.phoneNumber
        )
        cachedCNContactForCurrentUser = cnContact
        return cnContact
    }

    // MARK: - Get Current User Data Usage

    /// Returns the current user's total data usage, in kilobytes.
    ///
    /// - Returns: The total data usage, in kilobytes.
    ///
    /// - Throws: An `Exception` if any component's size cannot be resolved.
    func getCurrentUserDataUsage() async throws(Exception) -> Int {
        try await dataUsageService.getCurrentUserDataUsage()
    }

    // MARK: - Clear Cache

    /// Removes the cached device contact for the current user.
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
