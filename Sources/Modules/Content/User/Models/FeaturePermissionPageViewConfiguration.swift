//
//  FeaturePermissionPageViewConfiguration.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

extension FeaturePermissionPageView {
    struct Configuration: Equatable {
        // MARK: - Properties

        let accentColor: Color?
        let declineButtonAction: (() -> Void)?
        let enableButtonAction: () -> Void
        let iconConfig: SquareIconView.Configuration
        let subtitleText: String
        let titleText: String

        // MARK: - Init

        init(
            titleText: String,
            subtitleText: String,
            accentColor: Color? = nil,
            iconConfig: SquareIconView.Configuration,
            enableButtonAction: @escaping () -> Void,
            declineButtonAction: (() -> Void)? = nil,
        ) {
            self.titleText = titleText
            self.subtitleText = subtitleText
            self.accentColor = accentColor
            self.iconConfig = iconConfig
            self.enableButtonAction = enableButtonAction
            self.declineButtonAction = declineButtonAction
        }

        // MARK: - Equatable Conformance

        static func == (
            left: Configuration,
            right: Configuration
        ) -> Bool {
            let sameAccentColor = left.accentColor == right.accentColor
            let sameIconConfig = left.iconConfig == right.iconConfig
            let sameSubtitleText = left.subtitleText == right.subtitleText
            let sameTitleText = left.titleText == right.titleText

            guard sameAccentColor,
                  sameIconConfig,
                  sameSubtitleText,
                  sameTitleText else { return false }

            return true
        }
    }
}

extension FeaturePermissionPageView.Configuration {
    static var empty: FeaturePermissionPageView.Configuration {
        .init(
            titleText: "",
            subtitleText: "",
            iconConfig: .empty,
            enableButtonAction: {}
        )
    }
}

private extension SquareIconView.Configuration {
    static var empty: SquareIconView.Configuration {
        .init(
            backgroundColor: .black,
            overlay: .symbol(
                name: "exclamationmark.triangle.fill",
                foregroundColor: .yellow
            )
        )
    }
}
