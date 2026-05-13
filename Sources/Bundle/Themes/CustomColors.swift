//
//  CustomColors.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

/// Use this extension to define new ``ColoredItemType`` values for
/// specific UI elements.
///
/// Define a new ``ColoredItemType`` for each semantic color slot your
/// app introduces, then provide colors for it in your theme's palette:
///
/// ```swift
/// extension ColoredItemType {
///     static let cardBackground: ColoredItemType = .init("cardBackground")
/// }
/// ```
extension ColoredItemType {
    static let navigationBarButton: ColoredItemType = .init("navigationBarButton")
    static let receiverBubble: ColoredItemType = .init("receiverBubble")
    static let senderBubble: ColoredItemType = .init("senderBubble")
}

/// Use this extension to create custom `UIColor` properties that
/// resolve against the current theme.
///
/// Add computed properties that call ``UITheme/color(for:)`` on the
/// active theme:
///
/// ```swift
/// extension UIColor {
///     static var cardBackground: UIColor {
///         ThemeService.currentTheme.color(for: .cardBackground)
///     }
/// }
/// ```
@MainActor
extension UIColor {
    static var navigationBarButton: UIColor {
        ThemeService.currentTheme.color(for: .navigationBarButton)
    }

    static var receiverBubble: UIColor {
        ThemeService.currentTheme.color(for: .receiverBubble)
    }

    static var senderBubble: UIColor {
        ThemeService.currentTheme.color(for: .senderBubble)
    }
}

/// Use this extension to create custom SwiftUI `Color` properties
/// that resolve against the current theme.
///
/// Wrap the corresponding `UIColor` property in a `Color` initializer:
///
/// ```swift
/// extension Color {
///     static var cardBackground: Color { .init(uiColor: .cardBackground) }
/// }
/// ```
@MainActor
extension Color {
    static var navigationBarButton: Color {
        .init(uiColor: .navigationBarButton)
    }

    static var receiverBubble: Color {
        .init(uiColor: .receiverBubble)
    }

    static var senderBubble: Color {
        .init(uiColor: .senderBubble)
    }
}
