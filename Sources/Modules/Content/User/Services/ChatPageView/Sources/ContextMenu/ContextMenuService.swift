//
//  ContextMenuService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/// The service that manages message context menus.
///
/// ``ContextMenuService`` groups the two services that together provide the chat page's message
/// context menus: ``interaction`` installs and drives the menu gesture on each message cell, and
/// ``actionHandler`` builds each menu and performs its actions.
struct ContextMenuService {
    // MARK: - Properties

    /// The service that builds context menus and handles their actions.
    let actionHandler: ContextMenuActionHandlerService

    /// The service that manages context menu gesture interactions.
    let interaction: ContextMenuInteractionService

    private let viewController: ChatPageViewController

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    @MainActor
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)
        interaction = .init(viewController)
    }

    // MARK: - Dismiss Menu

    /// Dismisses the currently presented context menu.
    func dismissMenu() {
        Task { @MainActor in
            UIView.dismissCurrentContextMenu()
        }
    }
}
