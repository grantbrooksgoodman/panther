//
//  UIView+Extensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public extension UIView {
    func addInteraction(
        targetedPreviewProvider: @escaping TargetedPreviewProvider = { _ in nil },
        menuConfigurationProvider: @escaping MenuConfigurationProvider,
        style: ContextMenuStyle = .default,
        onInteractionBegan: (() -> Void)? = nil,
        onInteractionEnded: (() -> Void)? = nil
    ) {
        ContextMenuInteractor.shared.addInteraction(
            on: self,
            targetedPreviewProvider: targetedPreviewProvider,
            menuConfigurationProvider: menuConfigurationProvider,
            style: style,
            onInteractionBegan: onInteractionBegan,
            onInteractionEnded: onInteractionEnded
        )
    }

    func dismissContextMenu(completion: (() -> Void)? = nil) {
        ContextMenuInteractor.shared.dismissContextMenu(view: self, completion: completion)
    }

    static func dismissCurrentContextMenu(completion: (() -> Void)? = nil) {
        ContextMenuInteractor.shared.dismissCurrentContextMenu(completion: completion)
    }
}

extension UIView {
    /// Apply a scaling transformation from an anchorPoint
    func applyTransform(scale: CGFloat, anchorPoint: CGPoint) {
        layer.anchorPoint = anchorPoint
        let xPadding = 1 / scale * (anchorPoint.x - 0.5) * bounds.width
        let yPadding = 1 / scale * (anchorPoint.y - 0.5) * bounds.height
        transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xPadding, y: yPadding)
    }
}
