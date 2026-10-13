//
//  ContextMenuConfiguration.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

struct ContextMenuConfiguration {
    // MARK: - Properties

    let menu: Menu

    weak var accessoryView: UIView?
    weak var highlightableAccessory: ContextMenuHighlightable?

    // MARK: - Computed Properties

    @MainActor
    var uiContextMenuConfiguration: UIContextMenuConfiguration {
        .init(
            actionProvider: { _ -> UIMenu? in
                menu.uiMenu
            }
        )
    }

    // MARK: - Init

    init(
        accessoryView: UIView? = nil,
        highlightableAccessory: ContextMenuHighlightable? = nil,
        menu: Menu
    ) {
        self.accessoryView = accessoryView
        self.highlightableAccessory = highlightableAccessory
        self.menu = menu
    }
}
