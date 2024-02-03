//
//  UIView+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public extension UIView {
    func addShimmerEffect() {
        typealias Colors = AppConstants.Colors.UIViewShimmerEffect
        typealias Floats = AppConstants.CGFloats.UIViewShimmerEffect
        typealias Strings = AppConstants.Strings.UIViewShimmerEffect

        let gradientLayer = CAGradientLayer()
        let lightColor = UIColor(Colors.light).cgColor
        let darkColor = UIColor(Colors.dark).cgColor

        gradientLayer.colors = [darkColor, lightColor, darkColor]
        gradientLayer.frame = CGRect(
            x: -bounds.size.width,
            y: 0,
            width: Floats.gradientLayerFrameWidthMultiplier * bounds.size.width,
            height: bounds.size.height
        )

        gradientLayer.startPoint = .init(x: 0, y: Floats.gradientLayerStartPointY)
        gradientLayer.endPoint = .init(x: 1, y: Floats.gradientLayerEndPointY)
        gradientLayer.locations = [
            NSNumber(value: Floats.gradientLayerPrimaryLocation),
            NSNumber(value: Floats.gradientLayerSecondaryLocation),
            NSNumber(value: Floats.gradientLayerTertiaryLocation),
        ]

        layer.mask = gradientLayer

        let animation = CABasicAnimation(keyPath: Strings.animationKeyPath)
        animation.fromValue = [
            0,
            Floats.animationSecondaryFromValue,
            Floats.animationTertiaryFromValue,
        ]
        animation.toValue = [
            Floats.animationPrimaryToValue,
            Floats.animationSecondaryToValue,
            1,
        ]

        animation.duration = Floats.animationDuration
        animation.repeatCount = HUGE
        gradientLayer.add(animation, forKey: Strings.gradientLayerAnimationKey)
    }

    func removeShimmerEffect() {
        layer.mask = nil
    }
}
