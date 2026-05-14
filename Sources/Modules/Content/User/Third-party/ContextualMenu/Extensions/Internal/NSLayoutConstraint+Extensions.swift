//
//  NSLayoutConstraint+Extensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension NSLayoutConstraint {
    static func keeping(view: UIView, insideFrameOf contentView: UIView) -> [NSLayoutConstraint] {
        [
            // Keep accessory view above view top
            view.topAnchor.constraint(
                greaterThanOrEqualToSystemSpacingBelow: contentView.safeAreaLayoutGuide.topAnchor, multiplier: 1
            ),
            contentView.safeAreaLayoutGuide.bottomAnchor.constraint(
                greaterThanOrEqualToSystemSpacingBelow: view.bottomAnchor, multiplier: 1
            ),
            // Keep accessoryView between leading & trailing edges
            view.leadingAnchor.constraint(
                greaterThanOrEqualToSystemSpacingAfter: contentView.leadingAnchor, multiplier: 1
            ),
            contentView.trailingAnchor.constraint(
                greaterThanOrEqualToSystemSpacingAfter: view.trailingAnchor, multiplier: 1
            ),
        ]
    }

    func priority(_ prioriry: UILayoutPriority) -> NSLayoutConstraint {
        priority = prioriry
        return self
    }
}
