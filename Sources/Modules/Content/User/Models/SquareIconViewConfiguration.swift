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
    /// The appearance of a square icon.
    ///
    /// A configuration describes the icon's size, background color, overlay, and shadow.
    struct Configuration: EncodedHashable, Hashable {
        // MARK: - Types

        /// The content overlaid on a square icon.
        enum OverlayConfiguration {
            /// An image resource, with its foreground color, frame size relative to the icon,
            /// and font weight.
            case resource(
                _ resource: ImageResource,
                foregroundColor: Color = AppConstants.Colors.SquareIconView.overlaySymbolForeground,
                framePercentOfTotalSize: CGFloat = AppConstants.CGFloats.SquareIconView.overlayFrameHeightMultiplier,
                weight: Font.Weight? = nil
            )

            /// A symbol, with its foreground color, frame size relative to the icon, and font
            /// weight.
            case symbol(
                name: String,
                foregroundColor: Color = AppConstants.Colors.SquareIconView.overlaySymbolForeground,
                framePercentOfTotalSize: CGFloat = AppConstants.CGFloats.SquareIconView.overlayFrameHeightMultiplier,
                weight: Font.Weight? = nil
            )

            /// A text string, with its font and foreground color.
            case text(
                string: String,
                font: ComponentKit.Font = .system(scale: .custom(AppConstants.CGFloats.SquareIconView.overlayTextFontScale)),
                foregroundColor: Color = AppConstants.Colors.SquareIconView.overlaySymbolForeground
            )
        }

        // MARK: - Properties

        /// The icon's background color.
        let backgroundColor: Color

        /// A Boolean value that indicates whether the icon casts a shadow.
        let includesShadow: Bool

        /// The content overlaid on the icon.
        let overlay: OverlayConfiguration

        /// The size of the icon.
        let size: CGSize

        // MARK: - Computed Properties

        /// The strings that collectively define this instance's identity for hashing
        /// purposes, sorted alphabetically.
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

        /// Creates a square icon configuration.
        ///
        /// - Parameters:
        ///   - size: The size of the icon. The default is the standard icon size.
        ///   - backgroundColor: The icon's background color.
        ///   - overlay: The content overlaid on the icon.
        ///   - includesShadow: A Boolean value that indicates whether the icon casts a
        ///     shadow. The default is `false`.
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

        // MARK: - Equatable Conformance

        /// Returns a Boolean value that indicates whether two configurations are equal.
        static func == (
            left: Configuration,
            right: Configuration
        ) -> Bool {
            left.encodedHash == right.encodedHash
        }

        // MARK: - Hashable Conformance

        /// Hashes the configuration by combining its encoded hash.
        func hash(into hasher: inout Hasher) {
            hasher.combine(encodedHash)
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
