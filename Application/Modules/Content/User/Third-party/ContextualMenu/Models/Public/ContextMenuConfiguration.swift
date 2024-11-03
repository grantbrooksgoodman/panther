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

public struct ContextMenuConfiguration {
    // MARK: - Properties

    let menu: Menu

    weak var accessoryView: UIView?

    // MARK: - Computed Properties

    public var uiContextMenuConfiguration: UIContextMenuConfiguration {
        .init(
            actionProvider: { _ -> UIMenu? in
                menu.uiMenu
            }
        )
    }

    // MARK: - Init

    public init(accessoryView: UIView? = nil, menu: Menu) {
        self.accessoryView = accessoryView
        self.menu = menu
    }
}
