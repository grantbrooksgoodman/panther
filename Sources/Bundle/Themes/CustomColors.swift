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
import UIKit

/* Proprietary */
import AppSubsystem

/**
 Use this extension to define new colorable item types for specific UI elements.
 */
public extension ColoredItemType {
    static let listViewBackground: ColoredItemType = .init("listViewBackground")
    static let receiverBubble: ColoredItemType = .init("receiverBubble")
    static let senderBubble: ColoredItemType = .init("senderBubble")
}

/**
 Use this extension to create custom `UIColor` types based on the current theme.
 */
public extension UIColor {
    static var listViewBackground: UIColor { ThemeService.currentTheme.color(for: .listViewBackground) }
    static var receiverBubble: UIColor { ThemeService.currentTheme.color(for: .receiverBubble) }
    static var senderBubble: UIColor { ThemeService.currentTheme.color(for: .senderBubble) }
}

/**
 Provided to create convenience initializers for custom `Color` types.
 */
public extension Color {
    static var listViewBackground: Color { .init(uiColor: .listViewBackground) }
    static var receiverBubble: Color { .init(uiColor: .receiverBubble) }
    static var senderBubble: Color { .init(uiColor: .senderBubble) }
}
