//
//  OnboardingNavigator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct OnboardingNavigatorState: NavigatorState {
    // MARK: - Types

    public enum ModalPaths: Paths {}

    public enum SeguePaths: Paths {
        case authCode
        case permission
        case selectLanguage
        case signIn
        case verifyNumber
    }

    public enum SheetPaths: Paths {}

    // MARK: - Properties

    public var modal: ModalPaths?
    public var sheet: SheetPaths?
    public var stack: [SeguePaths] = []
}

public enum OnboardingNavigator {
    static func navigate(to route: RootNavigationService.Route.OnboardingRoute, on state: inout OnboardingNavigatorState) {
        switch route {
        case .pop:
            guard !state.stack.isEmpty else { return }
            state.stack.removeLast()

        case let .push(path):
            state.stack.append(path)

        case let .stack(paths):
            state.stack = paths
        }
    }
}

public extension RootNavigationService.Route {
    enum OnboardingRoute {
        case pop
        case push(OnboardingNavigatorState.SeguePaths)
        case stack([OnboardingNavigatorState.SeguePaths])
    }
}
