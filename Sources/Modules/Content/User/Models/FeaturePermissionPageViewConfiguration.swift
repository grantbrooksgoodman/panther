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
    /// The content and actions of a feature permission page.
    ///
    /// Use a configuration to describe the page's icon, title, subtitle, and the actions its
    /// enable and decline buttons perform.
    struct Configuration: Equatable {
        // MARK: - Properties

        /// The accent color applied to the page, or `nil` to use the default.
        let accentColor: Color?

        /// The action performed when the user taps the decline button. Pass `nil` for no
        /// action.
        let declineButtonAction: (() -> Void)?

        /// The action performed when the user taps the enable button.
        let enableButtonAction: () -> Void

        /// The configuration that describes the page's icon.
        let iconConfig: SquareIconView.Configuration

        /// The text the subtitle displays.
        let subtitleText: String

        /// The text the title displays.
        let titleText: String

        // MARK: - Init

        /// Creates a feature permission page configuration.
        ///
        /// - Parameters:
        ///   - titleText: The text the title displays.
        ///   - subtitleText: The text the subtitle displays.
        ///   - accentColor: The accent color applied to the page, or `nil` to use the default.
        ///     The default is `nil`.
        ///   - iconConfig: The configuration that describes the page's icon.
        ///   - enableButtonAction: The action performed when the user taps the enable button.
        ///   - declineButtonAction: The action performed when the user taps the decline
        ///     button. Pass `nil` for no action. The default is `nil`.
        init(
            titleText: String,
            subtitleText: String,
            accentColor: Color? = nil,
            iconConfig: SquareIconView.Configuration,
            enableButtonAction: @escaping () -> Void,
            declineButtonAction: (() -> Void)? = nil
        ) {
            self.titleText = titleText
            self.subtitleText = subtitleText
            self.accentColor = accentColor
            self.iconConfig = iconConfig
            self.enableButtonAction = enableButtonAction
            self.declineButtonAction = declineButtonAction
        }

        // MARK: - Equatable Conformance

        /// Returns a Boolean value that indicates whether two configurations are equal.
        ///
        /// Equality disregards the button actions.
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
    /// An empty placeholder configuration.
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
