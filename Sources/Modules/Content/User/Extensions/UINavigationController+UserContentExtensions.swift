//
//  UINavigationController+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension UINavigationController {
    /// Lays out the navigation controller's subviews, minimizing the top item's back button
    /// display mode.
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }
}
