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

struct ContextMenuService {
    // MARK: - Properties

    let actionHandler: ContextMenuActionHandlerService
    let interaction: ContextMenuInteractionService

    private let viewController: ChatPageViewController

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)
        interaction = .init(viewController)
    }

    // MARK: - Dismiss Menu

    func dismissMenu() {
        Task { @MainActor in
            UIView.dismissCurrentContextMenu()
        }
    }
}
