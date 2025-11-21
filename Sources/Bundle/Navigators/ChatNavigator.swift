//
//  ChatNavigator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct ChatNavigatorState: NavigatorState {
    // MARK: - Types

    public enum ModalPaths: Paths {}

    public enum SeguePaths: Paths {}

    public enum SheetPaths: Paths {
        case contactSelector
    }

    // MARK: - Properties

    public var modal: ModalPaths?
    public var sheet: SheetPaths?
    public var stack: [SeguePaths] = []
}

public enum ChatNavigator {
    static func navigate(to route: RootNavigationService.Route.ChatRoute, on state: inout ChatNavigatorState) {
        switch route {
        case let .sheet(path):
            state.sheet = path
        }
    }
}

public extension RootNavigationService.Route {
    enum ChatRoute {
        case sheet(ChatNavigatorState.SheetPaths?)
    }
}
