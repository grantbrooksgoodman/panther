//
//  RootNavigator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct RootNavigatorState: NavigatorState {
    // MARK: - Types

    public enum ModalPaths: Paths {
        case conversations
        case onboarding
        case splash
    }

    public enum SeguePaths: Paths {}

    public enum SheetPaths: Paths {
        case inviteLanguagePicker
    }

    // MARK: - Properties

    public var onboarding: OnboardingNavigatorState = .init()

    public var modal: ModalPaths?
    public var sheet: SheetPaths?
    public var stack: [SeguePaths] = []
}

public enum RootNavigator {
    static func navigate(to route: RootNavigationService.Route.RootRoute, on state: inout RootNavigatorState) {
        switch route {
        case let .modal(modal):
            state.modal = modal

        case let .sheet(sheet):
            state.sheet = sheet
        }
    }
}

public extension RootNavigationService.Route {
    enum RootRoute {
        case modal(RootNavigatorState.ModalPaths)
        case sheet(RootNavigatorState.SheetPaths?)
    }
}
