//
//  SquareIconViewConfiguration.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 28/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public extension SquareIconView {
    struct Configuration: EncodedHashable {
        // MARK: - Properties

        // Color
        public let backgroundColor: Color
        public let overlaySymbolForegroundColor: Color

        // Other
        public let includesShadow: Bool
        public let overlayFramePercentOfTotalSize: CGFloat
        public let overlaySymbolName: String
        public let overlaySymbolWeight: Font.Weight?
        public let size: CGSize

        // MARK: - Computed Properties

        public var hashFactors: [String] {
            [
                backgroundColor.description,
                includesShadow.description,
                overlayFramePercentOfTotalSize.description,
                overlaySymbolForegroundColor.description,
                overlaySymbolName,
                .init(overlaySymbolWeight?.hashValue ?? 0),
                size.debugDescription,
            ]
        }

        // MARK: - Init

        public init(
            size: CGSize = .init(
                width: AppConstants.CGFloats.SquareIconView.defaultFrameWidth,
                height: AppConstants.CGFloats.SquareIconView.defaultFrameHeight
            ),
            backgroundColor: Color,
            overlayFramePercentOfTotalSize: CGFloat = AppConstants.CGFloats.SquareIconView.overlayFrameHeightMultiplier,
            overlaySymbolName: String,
            overlaySymbolForegroundColor: Color = AppConstants.Colors.SquareIconView.overlaySymbolForeground,
            overlaySymbolWeight: Font.Weight? = nil,
            includesShadow: Bool = false
        ) {
            self.size = size
            self.backgroundColor = backgroundColor
            self.overlayFramePercentOfTotalSize = overlayFramePercentOfTotalSize
            self.overlaySymbolName = overlaySymbolName
            self.overlaySymbolForegroundColor = overlaySymbolForegroundColor
            self.overlaySymbolWeight = overlaySymbolWeight
            self.includesShadow = includesShadow
        }
    }
}
