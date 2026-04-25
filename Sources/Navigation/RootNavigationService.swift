//
//  RootNavigationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A convenience alias for the app's navigation coordinator.
///
/// Use `Navigation` wherever you need to reference the coordinator
/// type without repeating the full generic signature:
///
/// ```swift
/// @ObservedDependency(\.navigation) private var navigation: Navigation
/// ```
typealias Navigation = NavigationCoordinator<RootNavigationService>

/// The app's top-level navigation service.
///
/// `RootNavigationService` conforms to ``Navigating`` and defines the
/// complete set of navigation routes available in the app. When a
/// route is dispatched, this service delegates to the appropriate
/// navigator to apply the corresponding state change.
///
/// You do not interact with this type directly. Instead, call
/// ``NavigationCoordinator/navigate(to:)`` on the app's coordinator:
///
/// ```swift
/// @Dependency(\.navigation) var navigation: Navigation
/// navigation.navigate(to: .root(.modal(.home)))
/// ```
///
/// To introduce a new feature flow, add a ``Route`` case and
/// delegate to the corresponding navigator inside
/// ``navigate(to:on:)``.
struct RootNavigationService: Navigating {
    // MARK: - Type Aliases

    /// The navigation state type for this service.
    typealias State = RootNavigatorState

    // MARK: - Types

    /// The set of navigation actions available in the app.
    ///
    /// Each case groups routes by the navigator responsible for
    /// handling them.
    enum Route {
        case chat(ChatRoute)
        case onboarding(OnboardingRoute)
        /// A route handled by ``RootNavigator``.
        case root(RootRoute)
        case settings(SettingsRoute)
        case userContent(UserContentRoute)
    }

    // MARK: - Navigate to Route

    /// Dispatches the given route to the appropriate navigator.
    ///
    /// - Parameters:
    ///   - route: The navigation action to perform.
    ///   - state: The current navigation state, modified in place.
    func navigate(to route: Route, on state: inout RootNavigatorState) {
        switch route {
        case let .chat(chatRoute):
            ChatNavigator.navigate(to: chatRoute, on: &state.chat)

        case let .onboarding(onboardingRoute):
            OnboardingNavigator.navigate(to: onboardingRoute, on: &state.onboarding)

        case let .root(rootRoute):
            RootNavigator.navigate(to: rootRoute, on: &state)

        case let .settings(settingsRoute):
            SettingsNavigator.navigate(to: settingsRoute, on: &state.settings)

        case let .userContent(userContentRoute):
            UserContentNavigator.navigate(to: userContentRoute, on: &state.userContent)
        }
    }
}
