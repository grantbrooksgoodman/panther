//
//  Application+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

extension Application {
    // MARK: - Types

    /// A follow-up action to perform after a reset completes.
    ///
    /// Pass a procedure to ``Application/reset(preserveCurrentUserID:onCompletion:)`` to control
    /// what the user sees once local state has been cleared.
    enum ResetCompletionProcedure {
        /// Presents the splash page behind an activity indicator overlay, then suspends and
        /// terminates the app after a one-second delay.
        case exitGracefully

        /// Clears the user content navigation stack and presents the splash page.
        case navigateToSplash
    }

    // MARK: - Properties

    /// A Boolean value that indicates whether the app should use the legacy chat page interface.
    ///
    /// This property is always `true` when the app does not run with full iOS 26 compatibility.
    /// Otherwise, it mirrors ``Application/isInPrevaricationMode``, additionally returning `true`
    /// when the current user is signed in with a designated test account on a general-release
    /// build in the production environment.
    static var usesLegacyChatPageInterface: Bool {
        @Dependency(\.build.milestone) var buildMilestone: Build.Milestone
        @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
        guard UIApplication.isFullyV26Compatible else { return true }
        guard let currentUser else { return Application.isInPrevaricationMode }

        if [
            "15555555555",
            "18888888888",
        ].contains(currentUser.phoneNumber.compiledNumberString),
            buildMilestone == .generalRelease,
            Networking.config.environment == .production {
            return true
        }

        return Application.isInPrevaricationMode
    }

    // MARK: - Methods

    /// Dismisses every presented sheet in the app.
    ///
    /// This method clears the sheet navigation state for the chat, settings, and user content
    /// domains, dismisses any root-level sheets, and dismisses any sheets presented directly
    /// through UIKit.
    @MainActor
    static func dismissSheets() {
        @Dependency(\.navigation) var navigation: Navigation
        @Dependency(\.uiApplication) var uiApplication: UIApplication

        navigation.navigate(to: .chat(.sheet(.none)))
        navigation.navigate(to: .settings(.sheet(.none)))
        navigation.navigate(to: .userContent(.sheet(.none)))

        RootSheets.dismiss()
        uiApplication.dismissSheets()
    }

    /// Resets the app to a signed-out, freshly installed state.
    ///
    /// This method tears down the client session – clearing the outbox, advancing the session
    /// store's epoch, and stopping conversation observation – then clears all caches, erases the
    /// app's on-disk directories, removes the archives shared with the notification extension,
    /// resets persisted defaults, and signs the current user out. Persistent storage keys
    /// registered as permanent survive the reset.
    ///
    /// - Parameters:
    ///   - preserveCurrentUserID: A Boolean value that indicates whether the current user's
    ///     identifier should survive the reset. When `true`, current-user change observation also
    ///     continues uninterrupted. The default is `false`.
    ///   - procedure: The follow-up action to perform once the reset completes, dismissing all
    ///     presented sheets beforehand. Pass `nil` to leave the interface untouched. The default
    ///     is `nil`.
    @MainActor
    static func reset(
        preserveCurrentUserID: Bool = false,
        onCompletion procedure: ResetCompletionProcedure? = nil
    ) {
        @Dependency(\.appGroupDefaults) var appGroupDefaults: UserDefaults
        @Dependency(\.networking.auth) var auth: AuthDelegate
        @Dependency(\.clientSession) var clientSession: ClientSession
        @Dependency(\.coreKit) var core: CoreKit
        @Dependency(\.userDefaults) var defaults: UserDefaults
        @Dependency(\.navigation) var navigation: Navigation

        clientSession.outbox.removeAll()
        clientSession.store.advanceEpoch()
        clientSession.sync.conversationObserver.stopObserving()

        if !preserveCurrentUserID {
            clientSession.entity.user.stopObservingCurrentUserChanges()
        }

        core.utils.clearCaches()
        try? core.utils.eraseApplicationSupportDirectory()
        try? core.utils.eraseDocumentsDirectory()
        try? core.utils.eraseTemporaryDirectory()

        appGroupDefaults.removeObject(
            forKey: NotificationExtensionConstants.contactArchiveDefaultsKeyName
        )

        appGroupDefaults.removeObject(
            forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName
        )

        defaults.reset(preserving: .permanentAndSubsystemKeys(
            plus: preserveCurrentUserID ? [.userSessionService(.currentUserID)] : nil
        ))

        defaults.synchronize()
        RuntimeStorage.remove(.populatedTemporaryCaches)

        do {
            try auth.signOut()
        } catch {
            Logger.log(error)
        }

        guard let procedure else { return }
        Application.dismissSheets()

        switch procedure {
        case .exitGracefully:
            StatusBar.setIsHidden(true)
            core.ui.addOverlay(activityIndicator: .largeWhite)

            navigation.navigate(to: .root(.modal(.splash)))
            Task.delayed(by: .seconds(1)) { @MainActor in
                core.utils.exitGracefully()
            }

        case .navigateToSplash:
            navigation.navigate(to: .userContent(.stack([])))
            navigation.navigate(to: .root(.modal(.splash)))
        }
    }
}
