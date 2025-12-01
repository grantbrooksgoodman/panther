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

struct RootNavigatorState: NavigatorState {
    // MARK: - Types

    enum ModalPaths: Paths {
        case onboarding
        case splash
        case userContent
    }

    enum SeguePaths: Paths {}

    enum SheetPaths: Paths {}

    // MARK: - Properties

    var chat: ChatNavigatorState = .init()
    var onboarding: OnboardingNavigatorState = .init()
    var settings: SettingsNavigatorState = .init()
    var userContent: UserContentNavigatorState = .init()

    var modal: ModalPaths?
    var sheet: SheetPaths?
    var stack: [SeguePaths] = []
}

enum RootNavigator {
    static func navigate(to route: RootNavigationService.Route.RootRoute, on state: inout RootNavigatorState) {
        switch route {
        case let .modal(modal):
            state.modal = modal
        }
    }
}

extension RootNavigationService.Route {
    enum RootRoute {
        case modal(RootNavigatorState.ModalPaths)
    }
}
