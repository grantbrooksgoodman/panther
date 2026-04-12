//
//  CALayer+Extensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension CALayer {
    func animate(
        keyPath: WritableKeyPath<CALayer, some Any>, toValue: Float, duration: TimeInterval
    ) {
        let keyString = NSExpression(forKeyPath: keyPath).keyPath
        let animation = CABasicAnimation(keyPath: keyString)
        animation.fromValue = shadowOpacity
        animation.toValue = toValue
        animation.duration = duration
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        add(animation, forKey: animation.keyPath)
    }

    func applyShadow(_ parameters: ShadowParameters, overrideOpacity: Float? = nil) {
        shadowColor = parameters.color
        shadowOffset = parameters.offset
        shadowRadius = parameters.radius
        shadowOpacity = overrideOpacity ?? parameters.opacity
    }
}
