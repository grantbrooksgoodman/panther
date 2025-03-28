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

public typealias Navigation = NavigationCoordinator<RootNavigationService>

public struct RootNavigationService: Navigating {
    // MARK: - Type Aliases

    public typealias State = RootNavigatorState

    // MARK: - Types

    public enum Route {
        case onboarding(OnboardingRoute)
        case root(RootRoute)
        case settings(SettingsRoute)
        case userContent(UserContentRoute)
    }

    // MARK: - Navigate to Route

    public func navigate(to route: Route, on state: inout RootNavigatorState) {
        switch route {
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
