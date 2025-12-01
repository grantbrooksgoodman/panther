//
//  Menu.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

struct Menu {
    // MARK: - Properties

    let children: [MenuElement]

    // MARK: - Computed Properties

    var uiMenu: UIMenu {
        .init(children: children.map { $0.uiAction })
    }

    // MARK: - Init

    init(children: [MenuElement]) {
        self.children = children
    }
}
