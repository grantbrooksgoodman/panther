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

/* Proprietary */
import AppSubsystem

public extension UIView {
    // MARK: - Properties

    /// Leverages the `focusGroupIdentifier` property for use as a secondary identifier, separate from the view's `tag`.
    var identifier: String { focusGroupIdentifier ?? .init() }

    // MARK: - Methods

    func addShimmerEffect() {
        typealias Colors = AppConstants.Colors.UserContentExtensions.UIView
        typealias Floats = AppConstants.CGFloats.UserContentExtensions.UIView
        typealias Strings = AppConstants.Strings.UserContentExtensions.UIView

        let gradientLayer = CAGradientLayer()
        let lightColor = UIColor(Colors.shimmerEffectLight).cgColor
        let darkColor = UIColor(Colors.shimmerEffectDark).cgColor

        gradientLayer.colors = [darkColor, lightColor, darkColor]
        gradientLayer.frame = CGRect(
            x: -bounds.size.width,
            y: 0,
            width: Floats.shimmerEffectGradientLayerFrameWidthMultiplier * bounds.size.width,
            height: bounds.size.height
        )

        gradientLayer.startPoint = .init(x: 0, y: Floats.shimmerEffectGradientLayerStartPointY)
        gradientLayer.endPoint = .init(x: 1, y: Floats.shimmerEffectGradientLayerEndPointY)
        gradientLayer.locations = [
            NSNumber(value: Floats.shimmerEffectGradientLayerPrimaryLocation),
            NSNumber(value: Floats.shimmerEffectGradientLayerSecondaryLocation),
            NSNumber(value: Floats.shimmerEffectGradientLayerTertiaryLocation),
        ]

        layer.mask = gradientLayer

        let animation = CABasicAnimation(keyPath: Strings.shimmerEffectAnimationKeyPath)
        animation.fromValue = [
            0,
            Floats.shimmerEffectAnimationSecondaryFromValue,
            Floats.shimmerEffectAnimationTertiaryFromValue,
        ]
        animation.toValue = [
            Floats.shimmerEffectAnimationPrimaryToValue,
            Floats.shimmerEffectAnimationSecondaryToValue,
            1,
        ]

        animation.duration = Floats.shimmerEffectAnimationDuration
        animation.repeatCount = HUGE
        gradientLayer.add(animation, forKey: Strings.shimmerEffectGradientLayerAnimationKey)
    }

    func removeShimmerEffect() {
        layer.mask = nil
    }

    func setIdentifier(_ identifier: String) {
        focusGroupIdentifier = identifier
    }
}
