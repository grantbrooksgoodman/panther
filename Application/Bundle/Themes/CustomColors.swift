//
//  CustomColors.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI
import UIKit

/**
 Use this enum to define new color types for specific theme items.
 */
public enum ColoredItemType: String, Equatable {
    case accent
    case background
    case listViewBackground

    case navigationBarBackground
    case navigationBarTitle

    case receiverBubble
    case senderBubble

    case subtitleText
    case titleText
}

/**
 Use this extension to create custom `UIColor`s based on the current theme.
 */
public extension UIColor {
    static var accent: UIColor { theme.color(for: .accent) }
    static var background: UIColor { theme.color(for: .background) }
    static var listViewBackground: UIColor { theme.color(for: .listViewBackground) }

    static var navigationBarBackground: UIColor { theme.color(for: .navigationBarBackground) }
    static var navigationBarTitle: UIColor { theme.color(for: .navigationBarTitle) }

    static var receiverBubble: UIColor { theme.color(for: .receiverBubble) }
    static var senderBubble: UIColor { theme.color(for: .senderBubble) }

    static var subtitleText: UIColor { theme.color(for: .subtitleText) }
    static var titleText: UIColor { theme.color(for: .titleText) }

    private static var theme: UITheme { ThemeService.currentTheme }
}

/**
 Provided to create convenience initializers for custom `Color`s.
 */
public extension Color {
    static var accent: Color { .init(uiColor: .accent) }
    static var background: Color { .init(uiColor: .background) }
    static var listViewBackground: Color { .init(uiColor: .listViewBackground) }

    static var navigationBarBackground: Color { .init(uiColor: .navigationBarBackground) }
    static var navigationBarTitle: Color { .init(uiColor: .navigationBarTitle) }

    static var receiverBubble: Color { .init(uiColor: .receiverBubble) }
    static var senderBubble: Color { .init(uiColor: .senderBubble) }

    static var subtitleText: Color { .init(uiColor: .subtitleText) }
    static var titleText: Color { .init(uiColor: .titleText) }
}
