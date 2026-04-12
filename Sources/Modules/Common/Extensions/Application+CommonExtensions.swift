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

    @MainActor
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
