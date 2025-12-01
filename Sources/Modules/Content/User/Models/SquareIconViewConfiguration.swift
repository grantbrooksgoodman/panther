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

extension SquareIconView {
    struct Configuration: EncodedHashable {
        // MARK: - Types

        enum OverlayConfiguration {
            case resource(
                _ resource: ImageResource,
                foregroundColor: Color = AppConstants.Colors.SquareIconView.overlaySymbolForeground,
                framePercentOfTotalSize: CGFloat = AppConstants.CGFloats.SquareIconView.overlayFrameHeightMultiplier,
                weight: Font.Weight? = nil
            )

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
        let backgroundColor: Color

        // Other
        let includesShadow: Bool
        let overlay: OverlayConfiguration
        let size: CGSize

        // MARK: - Computed Properties

        var hashFactors: [String] {
            [
                backgroundColor.description,
                includesShadow.description,
                overlay.foregroundColor.description,
                overlay.rawValue,
                overlay.framePercentOfTotalSize?.description ?? "",
                .init(overlay.weight?.hashValue ?? 0),
                String(overlay.textFont?.scale.points ?? 0),
                String(overlay.textFont?.type),
                String(overlay.textFont?.type.name),
                size.debugDescription,
            ].sorted()
        }

        // MARK: - Init

        init(
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
        case let .resource(_, foregroundColor, _, _): foregroundColor
        case let .symbol(name: _, foregroundColor, _, _): foregroundColor
        case let .text(string: _, _, foregroundColor): foregroundColor
        }
    }

    var framePercentOfTotalSize: CGFloat? {
        switch self {
        case let .resource(_, _, framePercentOfTotalSize, _): framePercentOfTotalSize
        case let .symbol(name: _, _, framePercentOfTotalSize, _): framePercentOfTotalSize
        case .text: nil
        }
    }

    var rawValue: String {
        switch self {
        case let .resource(resource, _, _, _): resource.hashValue.description
        case let .symbol(name: name, _, _, _): name
        case let .text(string: string, _, _): string
        }
    }

    var textFont: ComponentKit.Font? {
        switch self {
        case .resource,
             .symbol: nil
        case let .text(_, font, _): font
        }
    }

    var weight: Font.Weight? {
        switch self {
        case let .resource(_, _, _, weight): weight
        case let .symbol(name: _, _, _, weight): weight
        case .text: nil
        }
    }
}
