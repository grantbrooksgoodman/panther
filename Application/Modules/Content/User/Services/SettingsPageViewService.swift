//
//  SettingsPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation
import SwiftUI

/* 3rd-party */
import AlertKit
import CoreArchitecture

public final class SettingsPageViewService: Cacheable {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.build) private var build: Build
    @Dependency(\.buildInfoOverlayViewService) private var buildInfoOverlayViewService: BuildInfoOverlayViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.clientSession.moderation) private var moderationSession: ModerationSessionService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    public var cache: Cache
    public var emptyCache: Cache

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Init

    public init() {
        emptyCache = .init(
            [
                .cnContactForCurrentUser: NSNull(),
            ]
        )
        cache = emptyCache
    }

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

            func isCurrentTheme(_ theme: UITheme) -> Bool { theme.name == ThemeService.currentTheme.name }
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

            var defaultsKeysToKeep: [UserDefaultsKeyDomain] = UserDefaultsKeyDomain.permanentKeys
            defaultsKeysToKeep.append(.app(.userSessionService(.currentUserID)))
            defaults.reset(keeping: defaultsKeysToKeep)

            @Persistent(.didClearCaches) var didClearCaches: Bool?
            didClearCaches = true
            services.analytics.logEvent(.clearCaches)

            var actions = [AKAction("Exit", style: .destructivePreferred, effect: { exit(0) })]
            if build.developerModeEnabled {
                let reloadAction = AKAction("Reload") {
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
                if let exception = await services.notification.modifyBadgeNumber(.set(to: 0)) {
                    Logger.log(exception)
                }

                core.utils.clearCaches()
                core.utils.eraseDocumentsDirectory()
                core.utils.eraseTemporaryDirectory()

                defaults.reset(keeping: UserDefaultsKeyDomain.permanentKeys)

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
                    await self.uiApplication.keyWindow?.addOverlay(alpha: 0.5, activityIndicator: (.large, .white))

                    if let exception = await self.userSession.deleteAccount() {
                        await self.uiApplication.keyWindow?.removeOverlay()
                        Logger.log(exception, with: .toast())
                        return
                    }

                    await self.uiApplication.keyWindow?.removeOverlay()

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
                RootSheets.present(.inviteQRCodePageView)
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

    public func sendFeedbackButtonTapped() {
        buildInfoOverlayViewService.sendFeedbackButtonTapped()
    }

    public func signOutButtonTapped() {
        Task { @MainActor in
            let signOutAction: AKAction = .init("Sign Out", style: .destructivePreferred) {
                Task {
                    self.core.utils.clearCaches()
                    self.core.utils.eraseDocumentsDirectory()
                    self.core.utils.eraseTemporaryDirectory()

                    if let exception = await self.services.notification.modifyBadgeNumber(.set(to: 0)) {
                        Logger.log(exception)
                    }

                    if let currentUser = self.userSession.currentUser,
                       let pushToken = self.services.notification.pushToken {
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
                    self.defaults.reset(keeping: UserDefaultsKeyDomain.permanentKeys)
                    self.navigationCoordinator.navigate(to: .onboarding(.stack([])))
                    self.navigationCoordinator.navigate(to: .root(.modal(.onboarding)))
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
    public func developerModeListItems() -> [StaticListItem]? {
        func overrideLanguageCodeButtonTapped() {
            guard RuntimeStorage.retrieve(.overriddenLanguageCode) == nil else {
                guard let currentUser = userSession.currentUser else { return }
                let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()

                alertKitConfig.overrideTargetLanguageCode(currentUser.languageCode)
                RuntimeStorage.remove(.overriddenLanguageCode)
                core.hud.showSuccess(text: "Set to \(languageName)")
                uiApplication.keyWindow?.rootViewController?.dismiss(animated: true)
                return
            }

            alertKitConfig.overrideTargetLanguageCode("en")
            RuntimeStorage.store("en", as: .overriddenLanguageCode)
            core.hud.showSuccess(text: "Set to English")
            uiApplication.keyWindow?.rootViewController?.dismiss(animated: true)
        }

        typealias Colors = AppConstants.Colors.SettingsPageView

        guard build.stage != .generalRelease else { return nil }

        var items = [StaticListItem]()

        if build.developerModeEnabled,
           let currentUser = userSession.currentUser,
           currentUser.languageCode != "en" {
            let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()
            let restoreLanguageCodeString = "\(Strings.restoreLanguageCodeButtonTextPrefix) \(languageName)"
            let overrideOrRestore = RuntimeStorage.retrieve(.overriddenLanguageCode) == nil ? Strings.overrideLanguageCodeButtonText : restoreLanguageCodeString

            items.append(
                .init(
                    title: overrideOrRestore,
                    imageData: (.init(systemName: Strings.overrideLanguageCodeButtonImageSystemName), Colors.overrideLanguageCodeButtonImageForeground),
                    action: overrideLanguageCodeButtonTapped
                )
            )
        }

        if !build.developerModeEnabled {
            items.append(
                .init(
                    title: Strings.toggleDeveloperModeButtonText,
                    imageData: (.init(systemName: Strings.toggleDeveloperModeButtonImageSystemName), Colors.toggleDeveloperModeButtonImageForeground),
                    action: { DevModeService.promptToToggle() }
                )
            )
        }

        return items
    }

    // MARK: - Fetch CNContact for Current User

    /// `.viewAppeared`
    public func fetchCNContactForCurrentUser() async -> Callback<CNContact, Exception> {
        if let cachedValue = cache.value(forKey: .cnContactForCurrentUser) as? CNContact {
            return .success(cachedValue)
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
            cache.set(cnContact, forKey: .cnContactForCurrentUser)
            return .success(cnContact)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Clear Cache

    public func clearCache() {
        CacheDomain.SettingsPageViewServiceCacheDomainKey.allCases.forEach { cache.removeObject(forKey: .settingsPageViewService($0)) }
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum SettingsPageViewServiceCacheDomainKey: String, CaseIterable, Equatable {
        case cnContactForCurrentUser
    }
}

private extension Cache {
    convenience init(_ objects: [CacheDomain.SettingsPageViewServiceCacheDomainKey: Any]) {
        var mappedObjects = [CacheDomain: Any]()
        objects.forEach { object in
            mappedObjects[.settingsPageViewService(object.key)] = object.value
        }
        self.init(mappedObjects)
    }

    func set(_ value: Any, forKey key: CacheDomain.SettingsPageViewServiceCacheDomainKey) {
        set(value, forKey: .settingsPageViewService(key))
    }

    func value(forKey key: CacheDomain.SettingsPageViewServiceCacheDomainKey) -> Any? {
        value(forKey: .settingsPageViewService(key))
    }
}
