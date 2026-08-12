//
//  SquareIconViewConfiguration+UserContentExtensions.swift
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

extension SquareIconView.Configuration {
    /// Returns the square icon configuration for the AI-enhanced translations feature.
    ///
    /// - Parameters:
    ///   - backgroundColor: The icon's background color.
    ///   - includesShadow: A Boolean value that determines whether the icon includes a shadow.
    ///
    /// - Returns: The icon configuration.
    static func aiEnhancedTranslationsIcon(
        backgroundColor: Color = .init(uiColor: .systemBlue),
        includesShadow: Bool = false
    ) -> SquareIconView.Configuration {
        .init(
            backgroundColor: backgroundColor,
            overlay: .symbol(name: "sparkles"),
            includesShadow: includesShadow
        )
    }

    /// Returns the square icon configuration for the PenPals feature.
    ///
    /// - Parameters:
    ///   - backgroundColor: The icon's background color.
    ///   - includesShadow: A Boolean value that determines whether the icon includes a shadow.
    ///
    /// - Returns: The icon configuration.
    static func penPalsIcon(
        backgroundColor: Color = .purple,
        includesShadow: Bool = false
    ) -> SquareIconView.Configuration {
        .init(
            backgroundColor: backgroundColor,
            overlay: .symbol(name: "figure.2"),
            includesShadow: includesShadow
        )
    }
}
