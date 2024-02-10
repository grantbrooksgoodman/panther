//
//  AppConstants+DeliveryProgressIndicatorService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 09/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum DeliveryProgressIndicatorService {
        public static let animationDelay: CGFloat = 1
        public static let animationDuration: CGFloat = 0.2

        public static let timerProgressIncrement: CGFloat = 0.001
        public static let timerProgressIncrementThreshold: CGFloat = 0.9

        public static let timerTimeInterval: CGFloat = 0.01
        public static let viewFrameHeight: CGFloat = 2
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum DeliveryProgressIndicatorService {
        public static let viewSemanticTag = "DELIVERY_PROGRESS_VIEW"
    }
}
