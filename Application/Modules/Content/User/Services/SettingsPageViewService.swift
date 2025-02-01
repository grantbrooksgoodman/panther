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

public final class SettingsPageViewService {
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
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.clientSession.moderation) private var moderationSession: ModerationSessionService
    @Dependency(\.reportDelegate) private var reportDelegate: ReportDelegate
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    @Cached(CacheKey.cnContactForCurrentUser) private var cachedCNContactForCurrentUser: CNContact?
    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Init

    public init() {}

    // MARK: - Reducer Action Handlers

    public func blockedUsersButtonTapped() {
        Task {
            guard let exception = await moderationSession.unblockUsers() else { return }
            Logger.log(exception, with: .toast())
        }
    }

    public func changeThemeButtonTapped() {
        Task {
            var actions = [AKAction]()

            func isCurrentTheme(_ theme: UITheme) -> Bool { theme.encodedHash == ThemeService.currentTheme.encodedHash }
            func themeName(_ theme: UITheme) -> String { RuntimeStorage.languageCode == "en" ? theme.name : (theme.nonEnglishName ?? theme.name) }

            actions = AppTheme.allCases.map { appTheme in
                .init(
                    isCurrentTheme(appTheme.theme) ? "\(themeName(appTheme.theme)) (Applied)" : themeName(appTheme.theme),
                    isEnabled: !isCurrentTheme(appTheme.theme)
                ) {
                    ThemeService.setTheme(appTheme.theme)
                }
            }

            await AKActionSheet(title: "Change Theme", actions: actions).present()
        }
    }

    public func clearCachesButtonTapped() {
        @Sendable
        func clearCaches() async {
            core.utils.clearCaches()
            core.utils.eraseDocumentsDirectory()
            core.utils.eraseTemporaryDirectory()

            var defaultsKeysToKeep: [UserDefaultsKey] = UserDefaultsKey.permanentKeys
            defaultsKeysToKeep.append(.userSessionService(.currentUserID))
            defaults.reset(keeping: defaultsKeysToKeep)

            @Persistent(.didClearCaches) var didClearCaches: Bool?
            didClearCaches = true
            services.analytics.logEvent(.clearCaches)

            var actions = [AKAction("Exit", style: .destructivePreferred, effect: { exit(0) })]
            if build.developerModeEnabled {
                let reloadAction = AKAction("Reload") {
                    self.navigationCoordinator.navigate(to: .userContent(.sheet(.none)))
                    self.navigationCoordinator.navigate(to: .root(.modal(.splash)))
                }

                actions.insert(reloadAction, at: 0)
            }

            await AKAlert(
                message: "Caches have been cleared. \(build.developerModeEnabled ? "" : "You must now restart the app.")",
                actions: actions
            ).present()
        }

        Task {
            let confirmed = await AKConfirmationAlert(
                title: "Clear Caches", // swiftlint:disable:next line_length
                message: "Are you sure you'd like to clear all caches?\n\nThis may fix some issues, but can also temporarily slow down the app while indexes rebuild.\(build.developerModeEnabled ? "" : "\n\nYou will need to restart the app for this to take effect.")",
                confirmButtonStyle: .destructivePreferred
            ).present()

            guard confirmed else { return }
            await clearCaches()
        }
    }

    public func deleteAccountButtonTapped() {
        Task {
            @Sendable
            func clearCachesAndExit() async {
                if let exception = await services.notification.setBadgeNumber(0, updateHostedValue: false) {
                    Logger.log(exception)
                }

                core.utils.clearCaches()
                core.utils.eraseDocumentsDirectory()
                core.utils.eraseTemporaryDirectory()

                defaults.reset(keeping: UserDefaultsKey.permanentKeys)

                exit(0)
            }

            let confirmed = await AKConfirmationAlert(
                title: "Delete Account", // swiftlint:disable:next line_length
                message: "Are you sure you'd like to delete your account? All user data will be deleted.\n\nIf you wish to continue using ⌘\(build.finalName)⌘, you will need to create a new account.\n\nAn app restart is required for this process to complete.",
                confirmButtonStyle: .destructivePreferred
            ).present()

            guard confirmed else { return }
            let deleteAccountAction: AKAction = .init("Delete Account", style: .destructivePreferred) {
                Task {
                    await self.uiApplication.mainWindow?.addOverlay(
                        alpha: Floats.deleteAccountOverlayAlpha,
                        activityIndicator: (.large, .white)
                    )

                    if let exception = self.userSession.stopObservingCurrentUserChanges() {
                        Logger.log(exception)
                    }

                    if let exception = await self.userSession.deleteAccount() {
                        await self.uiApplication.mainWindow?.removeOverlay()
                        Logger.log(exception, with: .toast())
                        return
                    }

                    await self.uiApplication.mainWindow?.removeOverlay()

                    let exitAction: AKAction = .init("Exit", style: .destructivePreferred) {
                        Task { await clearCachesAndExit() }
                    }

                    await AKAlert(
                        message: "Your account has been deleted. You must now restart the app.",
                        actions: [exitAction]
                    ).present()
                }
            }

            await AKActionSheet(actions: [deleteAccountAction]).present()
        }
    }

    public func inviteFriendsButtonTapped() {
        Task {
            let sendTextMessageAction: AKAction = .init("Send Text Message") {
                Task { @MainActor in
                    if let exception = await self.services.invite.presentInvitationPrompt() {
                        Logger.log(exception, with: .toast())
                    }
                }
            }

            let showQRCodeAction: AKAction = .init("Show QR Code") {
                self.navigationCoordinator.navigate(to: .settings(.sheet(.inviteQRCode)))
            }

            await AKActionSheet(
                title: "Invite Friends",
                actions: [sendTextMessageAction, showQRCodeAction]
            ).present()
        }
    }

    public func leaveReviewButtonTapped() {
        guard let url = URL(string: Strings.reviewOnAppStoreURLString) else { return }
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }

    public func penPalsParticipantSwitchToggled(on: Bool) {
        Task { @MainActor in
            guard on else {
                if let exception = await services.penPals.setDidGrantPenPalsPermission(false) {
                    Logger.log(exception, with: .toastInPrerelease)
                }

                return
            }

            RootSheets.present(.penPalsPermissionPageView)
        }
    }

    /// `.longPressGestureRecognized`
    public func promptToEnterPrereleaseMode() {
        Task {
            @Persistent(.buildMilestoneString) var buildMilestoneString: String?
            guard build.milestone == .generalRelease else {
                let confirmed = await AKConfirmationAlert(
                    title: "Exit Prerelease Mode",
                    message: "Are you sure you'd like to exit Prerelease Mode? An app restart is required for this to take effect.",
                    confirmButtonTitle: "Exit",
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
                        .init("Try Again", style: .preferred) { self.promptToEnterPrereleaseMode() },
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

    public func sendFeedbackButtonTapped() {
        Task {
            await AKActionSheet(
                title: "File a Report",
                actions: [
                    .init("Send Feedback") { self.reportDelegate.sendFeedback() },
                    .init("Report Bug") { self.reportDelegate.reportBug() },
                ]
            ).present()
        }
    }

    public func signOutButtonTapped() {
        Task { @MainActor in
            let signOutAction: AKAction = .init("Sign Out", style: .destructivePreferred) {
                Task {
                    self.userSession.stopObservingCurrentUserChanges()

                    self.core.utils.clearCaches()
                    self.core.utils.eraseDocumentsDirectory()
                    self.core.utils.eraseTemporaryDirectory()

                    if let exception = await self.services.notification.setBadgeNumber(0, updateHostedValue: false) {
                        Logger.log(exception)
                    }

                    if let currentUser = self.userSession.currentUser,
                       let pushToken = self.services.pushToken.currentToken {
                        let filteredPushTokens = (currentUser.pushTokens ?? []).filter { $0 != pushToken }
                        let updateValueResult = await currentUser.updateValue(
                            filteredPushTokens.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : filteredPushTokens,
                            forKey: .pushTokens
                        )

                        switch updateValueResult {
                        case let .failure(exception):
                            Logger.log(exception)

                        default: ()
                        }
                    }

                    self.services.analytics.logEvent(.logOut)
                    self.defaults.reset(keeping: UserDefaultsKey.permanentKeys)

                    self.navigationCoordinator.navigate(to: .userContent(.sheet(.none)))
                    self.core.gcd.after(.milliseconds(Floats.signOutNavigationDelayMilliseconds)) {
                        self.navigationCoordinator.navigate(to: .onboarding(.stack([])))
                        self.navigationCoordinator.navigate(to: .root(.modal(.onboarding)))
                    }
                }
            }

            await AKActionSheet(actions: [signOutAction]).present()
        }
    }

    /// `.longPressGestureRecognized`
    public func setClipboardWithHapticFeedback(_ string: String) {
        uiPasteboard.string = string
        services.haptics.generateFeedback(.heavy)
    }

    // MARK: - Developer Mode List Items

    /// `.viewAppeared`
    public func developerModeListItems() -> [ListRowView.Configuration]? {
        func overrideLanguageCodeButtonTapped() {
            guard RuntimeStorage.retrieve(.overriddenLanguageCode) == nil else {
                guard let currentUser = userSession.currentUser else { return }
                let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()

                alertKitConfig.overrideTargetLanguageCode(currentUser.languageCode)
                RuntimeStorage.remove(.overriddenLanguageCode)
                core.hud.showSuccess(text: "Set to \(languageName)")
                uiApplication.mainWindow?.rootViewController?.dismiss(animated: true)
                return
            }

            alertKitConfig.overrideTargetLanguageCode("en")
            RuntimeStorage.store("en", as: .overriddenLanguageCode)
            core.hud.showSuccess(text: "Set to English")
            uiApplication.mainWindow?.rootViewController?.dismiss(animated: true)
        }

        typealias Colors = AppConstants.Colors.SettingsPageView
        guard build.milestone != .generalRelease else { return nil }
        var items = [ListRowView.Configuration]()

        if build.developerModeEnabled,
           let currentUser = userSession.currentUser,
           currentUser.languageCode != "en" {
            let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()
            let restoreLanguageCodeString = "\(Strings.restoreLanguageCodeButtonTextPrefix) \(languageName)"
            let overrideOrRestore = RuntimeStorage.retrieve(.overriddenLanguageCode) == nil ? Strings.overrideLanguageCodeButtonText : restoreLanguageCodeString

            items.append(
                .init(
                    .button(action: overrideLanguageCodeButtonTapped),
                    innerText: overrideOrRestore,
                    imageView: {
                        SquareIconView(
                            .init(
                                backgroundColor: Colors.overrideLanguageCodeButtonImageBackground,
                                overlaySymbolName: Strings.overrideLanguageCodeButtonImageSystemName
                            )
                        )
                    }
                )
            )
        }

        if !build.developerModeEnabled {
            items.append(
                .init(
                    .button { DevModeService.promptToToggle() },
                    innerText: Strings.toggleDeveloperModeButtonText,
                    imageView: {
                        SquareIconView(
                            .init(
                                backgroundColor: Colors.toggleDeveloperModeButtonImageBackground,
                                overlayFramePercentOfTotalSize: Floats.toggleDeveloperModeButtonOverlayFramePercentOfTotalSize,
                                overlaySymbolName: Strings.toggleDeveloperModeButtonImageSystemName,
                                overlaySymbolWeight: .bold
                            )
                        )
                    }
                )
            )
        }

        return items
    }

    // MARK: - Fetch CNContact for Current User

    /// `.viewAppeared`
    public func fetchCNContactForCurrentUser() async -> Callback<CNContact, Exception> {
        if let cachedCNContactForCurrentUser {
            return .success(cachedCNContactForCurrentUser)
        }

        guard let currentUser = userSession.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
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

    // MARK: - Clear Cache

    public func clearCache() {
        cachedCNContactForCurrentUser = nil
    }
}

// swiftlint:enable file_length type_body_length
