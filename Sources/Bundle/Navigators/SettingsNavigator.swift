//
//  SettingsNavigator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/09/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct SettingsNavigatorState: NavigatorState {
    // MARK: - Types

    public enum ModalPaths: Paths {}

    public enum SeguePaths: Paths {}

    public enum SheetPaths: Paths {
        case inviteQRCode
    }

    // MARK: - Properties

    public var modal: ModalPaths?
    public var sheet: SheetPaths?
    public var stack: [SeguePaths] = []
}

public enum SettingsNavigator {
    static func navigate(to route: RootNavigationService.Route.SettingsRoute, on state: inout SettingsNavigatorState) {
        switch route {
        case let .sheet(path):
            state.sheet = path
        }
    }
}

public extension RootNavigationService.Route {
    enum SettingsRoute {
        case sheet(SettingsNavigatorState.SheetPaths?)
    }
}
