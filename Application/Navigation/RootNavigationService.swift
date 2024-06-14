//
//  RootNavigationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct RootNavigationService: Navigating {
    // MARK: - Type Aliases

    public typealias State = RootNavigatorState

    // MARK: - Types

    public enum Route {
        case onboarding(OnboardingRoute)
        case root(RootRoute)
    }

    // MARK: - Navigate to Route

    public func navigate(to route: Route, on state: inout RootNavigatorState) {
        switch route {
        case let .onboarding(onboardingRoute):
            OnboardingNavigator.navigate(to: onboardingRoute, on: &state.onboarding)

        case let .root(rootRoute):
            RootNavigator.navigate(to: rootRoute, on: &state)
        }
    }
}
