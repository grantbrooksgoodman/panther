//
//  DeliveryProgressIndicatorProtocol.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol DeliveryProgressIndicator {
    func incrementDeliveryProgress(by: Float)
    func startAnimatingDeliveryProgress()
}
