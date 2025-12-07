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

struct ChatNavigatorState: NavigatorState {
    // MARK: - Types

    enum ModalPaths: Paths {}

    enum SeguePaths: Paths {}

    enum SheetPaths: Paths {
        case cameraPicker
        case contactSelector
        case photoPicker
    }

    // MARK: - Properties

    var modal: ModalPaths?
    var sheet: SheetPaths?
    var stack: [SeguePaths] = []
}

enum ChatNavigator {
    static func navigate(to route: RootNavigationService.Route.ChatRoute, on state: inout ChatNavigatorState) {
        switch route {
        case let .sheet(path):
            state.sheet = path
        }
    }
}

extension RootNavigationService.Route {
    enum ChatRoute {
        case sheet(ChatNavigatorState.SheetPaths?)
    }
}
