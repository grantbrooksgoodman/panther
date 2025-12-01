//
//  UserContentNavigator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct UserContentNavigatorState: NavigatorState {
    // MARK: - Types

    enum ModalPaths: Paths {}

    enum SeguePaths: Paths {
        case chat(Conversation, focusedMessageID: String? = nil)
    }

    enum SheetPaths: Paths {
        case newChat
        case settings
    }

    // MARK: - Properties

    var modal: ModalPaths?
    var sheet: SheetPaths?
    var stack: [SeguePaths] = []
}

enum UserContentNavigator {
    static func navigate(to route: RootNavigationService.Route.UserContentRoute, on state: inout UserContentNavigatorState) {
        switch route {
        case .pop:
            guard !state.stack.isEmpty else { return }
            state.stack.removeLast()

        case let .push(path):
            state.stack.append(path)

        case let .sheet(path):
            state.sheet = path

        case let .stack(paths):
            state.stack = paths
        }
    }
}

extension RootNavigationService.Route {
    enum UserContentRoute {
        case pop
        case push(UserContentNavigatorState.SeguePaths)
        case sheet(UserContentNavigatorState.SheetPaths?)
        case stack([UserContentNavigatorState.SeguePaths])
    }
}
