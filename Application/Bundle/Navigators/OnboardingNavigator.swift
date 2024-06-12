//
//  OnboardingNavigator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

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

    // MARK: - Properties

    public var modal: ModalPaths?
    public var stack: [SeguePaths] = []
}

public enum OnboardingNavigator {
    static func navigate(to route: RootNavigationService.Route.OnboardingRoute, on state: inout OnboardingNavigatorState) {
        switch route {
        case let .modal(modal):
            state.modal = modal

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
        case modal(OnboardingNavigatorState.ModalPaths?)
        case pop
        case push(OnboardingNavigatorState.SeguePaths)
        case stack([OnboardingNavigatorState.SeguePaths])
    }
}
