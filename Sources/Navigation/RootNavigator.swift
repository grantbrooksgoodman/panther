//
//  RootNavigator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct RootNavigatorState: NavigatorState {
    // MARK: - Types

    public enum ModalPaths: Paths {
        case onboarding
        case splash
        case userContent
    }

    public enum SeguePaths: Paths {}

    public enum SheetPaths: Paths {}

    // MARK: - Properties

    public var chat: ChatNavigatorState = .init()
    public var onboarding: OnboardingNavigatorState = .init()
    public var settings: SettingsNavigatorState = .init()
    public var userContent: UserContentNavigatorState = .init()

    public var modal: ModalPaths?
    public var sheet: SheetPaths?
    public var stack: [SeguePaths] = []
}

public enum RootNavigator {
    static func navigate(to route: RootNavigationService.Route.RootRoute, on state: inout RootNavigatorState) {
        switch route {
        case let .modal(modal):
            state.modal = modal
        }
    }
}

public extension RootNavigationService.Route {
    enum RootRoute {
        case modal(RootNavigatorState.ModalPaths)
    }
}
