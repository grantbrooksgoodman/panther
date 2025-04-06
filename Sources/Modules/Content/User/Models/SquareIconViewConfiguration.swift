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
import ComponentKit

public extension SquareIconView {
    struct Configuration: EncodedHashable {
        // MARK: - Types

        public enum OverlayConfiguration {
            case symbol(
                name: String,
                foregroundColor: Color = AppConstants.Colors.SquareIconView.overlaySymbolForeground,
                framePercentOfTotalSize: CGFloat = AppConstants.CGFloats.SquareIconView.overlayFrameHeightMultiplier,
                weight: Font.Weight? = nil
            )

            case text(
                string: String,
                font: ComponentKit.Font = .system(scale: .custom(AppConstants.CGFloats.SquareIconView.overlayTextFontScale)),
                foregroundColor: Color = AppConstants.Colors.SquareIconView.overlaySymbolForeground
            )
        }

        // MARK: - Properties

        // Color
        public let backgroundColor: Color

        // Other
        public let includesShadow: Bool
        public let overlay: OverlayConfiguration
        public let size: CGSize

        // MARK: - Computed Properties

        public var hashFactors: [String] {
            [
                backgroundColor.description,
                includesShadow.description,
                overlay.foregroundColor.description,
                overlay.rawValue,
                overlay.symbolFramePercentOfTotalSize?.description ?? "",
                .init(overlay.symbolWeight?.hashValue ?? 0),
                String(overlay.textFont?.scale.points ?? 0),
                String(overlay.textFont?.type),
                String(overlay.textFont?.type.name),
                size.debugDescription,
            ].sorted()
        }

        // MARK: - Init

        public init(
            size: CGSize = .init(
                width: AppConstants.CGFloats.SquareIconView.defaultFrameWidth,
                height: AppConstants.CGFloats.SquareIconView.defaultFrameHeight
            ),
            backgroundColor: Color,
            overlay: OverlayConfiguration,
            includesShadow: Bool = false
        ) {
            self.size = size
            self.backgroundColor = backgroundColor
            self.overlay = overlay
            self.includesShadow = includesShadow
        }
    }
}

private extension SquareIconView.Configuration.OverlayConfiguration {
    var foregroundColor: Color {
        switch self {
        case let .symbol(name: _, foregroundColor, _, _): return foregroundColor
        case let .text(string: _, _, foregroundColor): return foregroundColor
        }
    }

    var rawValue: String {
        switch self {
        case let .symbol(name: name, _, _, _): return name
        case let .text(string: string, _, _): return string
        }
    }

    var symbolFramePercentOfTotalSize: CGFloat? {
        switch self {
        case let .symbol(name: _, _, framePercentOfTotalSize, _): return framePercentOfTotalSize
        case .text: return nil
        }
    }

    var symbolWeight: Font.Weight? {
        switch self {
        case let .symbol(name: _, _, _, weight): return weight
        case .text: return nil
        }
    }

    var textFont: ComponentKit.Font? {
        switch self {
        case .symbol: return nil
        case let .text(_, font, _): return font
        }
    }
}
