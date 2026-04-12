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

struct Menu: @unchecked Sendable {
    // MARK: - Properties

    let children: [MenuElement]

    // MARK: - Computed Properties

    @MainActor
    var uiMenu: UIMenu {
        .init(children: children.map(\.uiAction))
    }

    // MARK: - Init

    init(children: [MenuElement]) {
        self.children = children
    }
}
