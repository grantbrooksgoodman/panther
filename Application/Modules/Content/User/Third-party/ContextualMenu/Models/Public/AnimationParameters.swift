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

public struct AnimationParameters {
    // MARK: - Properties

    public let curve: UIView.AnimationOptions
    public let damping: CGFloat
    public let duration: TimeInterval
    public let initialSpringVelocity: CGFloat

    // MARK: - Init

    public init(
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
