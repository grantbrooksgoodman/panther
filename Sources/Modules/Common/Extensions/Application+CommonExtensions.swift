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

extension Application {
    // MARK: - Types

    enum ResetCompletionProcedure {
        case exitGracefully
        case navigateToSplash
    }

    // MARK: - Methods

    static func dismissSheets() {
        @Dependency(\.navigation) var navigation: Navigation
        @Dependency(\.uiApplication) var uiApplication: UIApplication

        navigation.navigate(to: .chat(.sheet(.none)))
        navigation.navigate(to: .settings(.sheet(.none)))
        navigation.navigate(to: .userContent(.sheet(.none)))

        RootSheets.dismiss()
        uiApplication.dismissSheets()
    }

    static func reset(
        preserveCurrentUserID: Bool = false,
        onCompletion procedure: ResetCompletionProcedure? = nil
    ) {
        @Dependency(\.coreKit) var core: CoreKit
        @Dependency(\.userDefaults) var defaults: UserDefaults
        @Dependency(\.navigation) var navigation: Navigation
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        if !preserveCurrentUserID {
            userSession.stopObservingCurrentUserChanges()
            _ = userSession.setCurrentUser(nil)
        }

        core.utils.clearCaches()
        core.utils.eraseDocumentsDirectory()
        core.utils.eraseTemporaryDirectory()

        defaults.reset(preserving: .permanentAndSubsystemKeys(
            plus: preserveCurrentUserID ? [.userSessionService(.currentUserID)] : nil
        ))

        defaults.synchronize()

        guard let procedure else { return }
        switch procedure {
        case .exitGracefully:
            Application.dismissSheets()

            StatusBar.setIsHidden(true)
            core.ui.addOverlay(activityIndicator: .largeWhite)

            navigation.navigate(to: .root(.modal(.splash)))
            core.gcd.after(.seconds(1)) { core.utils.exitGracefully() }

        case .navigateToSplash:
            Application.dismissSheets()
            navigation.navigate(to: .userContent(.stack([])))
            navigation.navigate(to: .root(.modal(.splash)))
        }
    }

    static func toggleGlassTinting(on isEnabled: Bool) {
        @Dependency(\.userDefaults) var defaults: UserDefaults
        @Persistent(.isGlassTintingEnabled) var isGlassTintingEnabled: Bool?

        isGlassTintingEnabled = isEnabled
        defaults.synchronize() // NIT: Trying to force sync.

        NavigationBar.removeAllItemGlassTint()
        RootWindowScene.traitCollectionChanged()
    }
}
