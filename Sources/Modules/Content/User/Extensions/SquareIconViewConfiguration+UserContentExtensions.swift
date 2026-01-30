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
