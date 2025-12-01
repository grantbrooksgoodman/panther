//
//  AnimationParameters.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

struct AnimationParameters {
    // MARK: - Properties

    let curve: UIView.AnimationOptions
    let damping: CGFloat
    let duration: TimeInterval
    let initialSpringVelocity: CGFloat

    // MARK: - Init

    init(
        duration: TimeInterval = 0.3,
        damping: CGFloat = 1,
        initialSpringVelocity: CGFloat = 4,
        curve: UIView.AnimationOptions = .curveEaseIn
    ) {
        self.duration = duration
        self.damping = damping
        self.initialSpringVelocity = initialSpringVelocity
        self.curve = curve
    }
}
