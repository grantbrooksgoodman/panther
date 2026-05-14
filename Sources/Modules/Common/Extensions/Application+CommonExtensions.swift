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

    enum ResetCompletionProcedure {
        case exitGracefully
        case navigateToSplash
    }

    // MARK: - Properties

    static var usesLegacyChatPageInterface: Bool {
        @Dependency(\.build.milestone) var buildMilestone: Build.Milestone
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
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
        core.utils.eraseApplicationSupportDirectory()
        core.utils.eraseDocumentsDirectory()
        core.utils.eraseTemporaryDirectory()

        defaults.reset(preserving: .permanentAndSubsystemKeys(
            plus: preserveCurrentUserID ? [.userSessionService(.currentUserID)] : nil
        ))

        defaults.synchronize()
        RuntimeStorage.remove(.populatedTemporaryCaches)
        RuntimeStorage.remove(.updatedLastSignInDate)

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
