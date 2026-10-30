//
//  DevModeActions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/// Use this extension to add new actions to the Developer Mode menu.
///
/// Define ``DevModeAction`` instances in the option enums nested in ``AppActions`` and include
/// them in that enum's `actions` list to make them available on its page of the Developer Mode
/// menu:
///
/// ```swift
/// private static let resetOnboardingAction = DevModeAction(
///     title: "Reset Onboarding",
///     iconConfiguration: .init(
///         backgroundColor: .orange,
///         overlay: .symbol(name: "arrow.counterclockwise")
///     )
/// ) {
///     @Persistent(.hasSeenOnboarding) var hasSeenOnboarding: Bool?
///     hasSeenOnboarding = nil
/// }
/// ```
///
/// - Note: Developer Mode actions are available only in pre-release builds. The subsystem
/// hides them entirely in general-release builds.
extension DevModeAction {
    /// The delegate that supplies app-specific actions to the
    /// Developer Mode menu.
    struct AppActions: @MainActor AppSubsystem.Delegates.DevModeAppActionDelegate {
        // MARK: - Dependencies

        @Dependency(\.mainBundle) private var mainBundle: Bundle

        // MARK: - Properties

        /// The actions to display in the Developer Mode menu, sorted alphabetically by title.
        ///
        /// Each option group is a destination that pushes a page of its own actions. The
        /// subsystem reads this list each time the menu is presented or refreshed, so a computed
        /// list can reflect the app's current state.
        @MainActor
        var appActions: [DevModeAction] {
            var actions = [
                DangerZone.action,
                DatabaseOptions.action,
                UIOptions.action,
                UserOptions.action,
            ]

            if Networking.config.environment != .production,
               mainBundle.containsStagingAssets {
                actions.append(StagingModeOptions.action)
            }

            return actions.sorted { $0.title < $1.title }
        }
    }
}
