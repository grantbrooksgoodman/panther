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

public struct SettingsPageViewService {
    // MARK: - Type Aliases

    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Dependencies

    @Dependency(\.alertKitCore) private var akCore: AKCore
    @Dependency(\.build) private var build: Build
    @Dependency(\.buildInfoOverlayViewService) private var buildInfoOverlayViewService: BuildInfoOverlayViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Reducer Action Handlers

    public func clearCachesButtonTapped() {
        @Sendable
        func clearCaches() {
            core.utils.clearCaches()
            core.utils.eraseDocumentsDirectory()
            core.utils.eraseTemporaryDirectory()

            defaults.reset(keeping: [.app(.userSessionService(.currentUserID)),
                                     .core(.breadcrumbsCaptureEnabled),
                                     .core(.breadcrumbsCapturesAllViews),
                                     .core(.currentThemeID),
                                     .core(.developerModeEnabled),
                                     .core(.hidesBuildInfoOverlay)])

            services.analytics.logEvent(.clearCaches)

            let alert = AKAlert(
                message: "Caches have been cleared. You must now restart the app.",
                actions: [.init(title: "Exit", style: .destructivePreferred)],
                showsCancelButton: false
            )

            Task {
                _ = await alert.present()
                fatalError()
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

    public func leaveReviewButtonTapped() {
        guard let url = URL(string: Strings.reviewOnAppStoreURLString) else { return }
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }

    public func sendFeedbackButtonTapped() {
        buildInfoOverlayViewService.sendFeedbackButtonTapped()
    }

    /// `.longPressGestureRecognized`
    public func setClipboardWithHapticFeedback(_ string: String) {
        uiPasteboard.string = string
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - Developer Mode List Items

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

    public func fetchCnContactForCurrentUser() async -> Callback<CNContact, Exception> {
        guard let currentUser = userSession.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            ))
        }

        return await services.contact.firstCnContact(for: currentUser.phoneNumber)
    }
}
