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
import Redux

public final class SettingsPageViewService: Cacheable {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Dependencies

    @Dependency(\.alertKitCore) private var akCore: AKCore
    @Dependency(\.build) private var build: Build
    @Dependency(\.buildInfoOverlayViewService) private var buildInfoOverlayViewService: BuildInfoOverlayViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.rootNavigationCoordinator) private var navigationCoordinator: RootNavigationCoordinator
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    public var cache: Cache
    public var emptyCache: Cache

    private var defaultsKeysToKeep: [UserDefaultsKeyDomain] {
        [
            .app(.devModeService(.indicatesNetworkActivity)),
            .core(.breadcrumbsCaptureEnabled),
            .core(.breadcrumbsCapturesAllViews),
            .core(.currentThemeID),
            .core(.developerModeEnabled),
            .core(.hidesBuildInfoOverlay),
        ]
    }

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

    public func changeThemeButtonTapped() {
        Task {
            var actions = [AKAction]()
            var titleMap = [Int: String]()

            func isCurrentTheme(_ theme: UITheme) -> Bool { theme.name == ThemeService.currentTheme.name }
            func themeName(_ theme: UITheme) -> String { RuntimeStorage.languageCode == "en" ? theme.name : (theme.nonEnglishName ?? theme.name) }

            actions = AppTheme.allCases.map { .init(
                title: isCurrentTheme($0.theme) ? "\(themeName($0.theme)) (Applied)" : themeName($0.theme),
                style: .default,
                isEnabled: !isCurrentTheme($0.theme)
            ) }

            actions.forEach { titleMap[$0.identifier] = $0.title }

            let actionSheet = AKActionSheet(
                message: "Change Theme",
                actions: actions
            )

            let actionID = await actionSheet.present()
            guard actionID != -1,
                  let actionTitle = titleMap[actionID],
                  let correspondingCase = AppTheme.allCases.first(where: { themeName($0.theme) == actionTitle }) else { return }

            ThemeService.setTheme(correspondingCase.theme)
        }
    }

    public func clearCachesButtonTapped() {
        @Sendable
        func clearCaches() {
            core.utils.clearCaches()
            core.utils.eraseDocumentsDirectory()
            core.utils.eraseTemporaryDirectory()

            var defaultsKeysToKeep: [UserDefaultsKeyDomain] = [.app(.userSessionService(.currentUserID))]
            defaultsKeysToKeep.append(contentsOf: self.defaultsKeysToKeep)
            defaults.reset(keeping: defaultsKeysToKeep)

            @Persistent(.didClearCaches) var didClearCaches: Bool?
            didClearCaches = true
            services.analytics.logEvent(.clearCaches)

            let alert = AKAlert(
                message: "Caches have been cleared. You must now restart the app.",
                actions: [.init(title: "Exit", style: .destructivePreferred)],
                showsCancelButton: false
            )

            Task {
                _ = await alert.present()
                exit(0)
            }
        }

        Task {
            let alert = AKConfirmationAlert(
                title: "Clear Caches", // swiftlint:disable:next line_length
                message: "Are you sure you'd like to clear all caches?\n\nThis may fix some issues, but can also temporarily slow down the app while indexes rebuild.\n\nYou will need to restart the app for this to take effect.",
                confirmationStyle: .destructivePreferred
            )

            let didConfirm = await alert.present()
            guard didConfirm == 1 else { return }
            clearCaches()
        }
    }

    public func inviteFriendsButtonTapped() async -> Exception? {
        await services.invite.presentInvitationPrompt()
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
        Task {
            let actionSheet = AKActionSheet(actions: [.init(title: "Sign Out", style: .destructivePreferred)])

            let actionID = await actionSheet.present()
            guard actionID != -1 else { return }

            core.utils.clearCaches()
            core.utils.eraseDocumentsDirectory()
            core.utils.eraseTemporaryDirectory()

            defaults.reset(keeping: defaultsKeysToKeep)

            navigationCoordinator.setPage(.onboarding(.welcome))
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
            guard !akCore.languageCodeIsLocked else {
                guard let currentUser = userSession.currentUser else { return }
                let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()

                RuntimeStorage.remove(.overriddenLanguageCode)
                akCore.unlockLanguageCode(andSetTo: RuntimeStorage.languageCode)

                core.hud.showSuccess(text: "Set to \(languageName)")

                return
            }

            akCore.lockLanguageCode(to: "en")
            RuntimeStorage.store("en", as: .overriddenLanguageCode)
            core.hud.showSuccess(text: "Set to English")
        }

        typealias Colors = AppConstants.Colors.SettingsPageView

        guard build.stage != .generalRelease else { return nil }

        var items = [StaticListItem]()

        if build.developerModeEnabled,
           let currentUser = userSession.currentUser,
           currentUser.languageCode != "en" {
            let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()
            let restoreLanguageCodeString = "\(Strings.restoreLanguageCodeButtonTextPrefix) \(languageName)"
            let overrideOrRestore = akCore.languageCodeIsLocked ? restoreLanguageCodeString : Strings.overrideLanguageCodeButtonText

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
