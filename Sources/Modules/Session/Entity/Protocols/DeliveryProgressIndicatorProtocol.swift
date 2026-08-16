//
//  DeliveryProgressIndicatorProtocol.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A type that displays the progress of a message delivery.
@MainActor
protocol DeliveryProgressIndicator {
    /// Advances the displayed delivery progress by the given amount.
    ///
    /// - Parameter by: The amount to add to the current progress.
    func incrementDeliveryProgress(by: Float)

    /// Starts animating the delivery progress indicator.
    func startAnimatingDeliveryProgress()
}
