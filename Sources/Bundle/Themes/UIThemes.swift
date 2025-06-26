//
//  UIThemes.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/**
 Use this extension to build new UI themes.
 */
public extension UITheme {
    // MARK: - Type Aliases

    private typealias Item = UITheme.ColoredItem

    // MARK: - Types

    struct List: AppSubsystem.Delegates.UIThemeListDelegate {
        public var uiThemes: [UITheme] {
            [
                .appDefault,
                .bluesky,
                .dusk,
                .firebrand,
                .twilight,
            ]
        }
    }

    // MARK: - Themes

    static let appDefault: UITheme = .init(name: "Default", items: appDefaultColoredItems)
    static let bluesky: UITheme = .init(name: "Bluesky", items: blueskyColoredItems, style: .dark)
    static let dusk: UITheme = .init(name: "Dusk", items: duskColoredItems, style: .dark)
    static let firebrand: UITheme = .init(name: "Firebrand", items: firebrandColoredItems, style: .dark)
    static let prevaricationMode: UITheme = .init(name: "Prevarication Mode", items: prevaricationModeColoredItems, style: .light)
    static let twilight: UITheme = .init(name: "Twilight", items: twilightColoredItems, style: .dark)

    // MARK: - Colored Items

    private static var appDefaultColoredItems: [Item] {
        let accent = Item(
            .accent,
            set: UIApplication.v26FeaturesEnabled ? .init(.black, variant: .white) : .init(.systemBlue)
        )

        let background = Item(.background, set: .init(.white, variant: .black))
        let disabled = Item(.disabled, set: .init(.systemGray3))
        let groupedContentBackground = Item(.groupedContentBackground, set: .init(.init(hex: 0xF2F2F7), variant: .init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(.navigationBarBackground, set: .init(.init(hex: 0xF8F8F8), variant: .init(hex: 0x2A2A2C)))
        let navigationBarTitle = Item(.navigationBarTitle, set: .init(.black, variant: .white))
        let navigationBarButton = Item(.navigationBarButton, set: accent.set)

        let senderBubble = Item(.senderBubble, set: .init(.systemBlue))
        let receiverBubble = Item(.receiverBubble, set: .init(.init(hex: 0xE5E5EA), variant: .init(hex: 0x27252A)))

        let titleText = Item(.titleText, set: .init(.black, variant: .white))
        let subtitleText = Item(.subtitleText, set: .init(.gray))

        return [
            accent,
            background,
            disabled,
            groupedContentBackground,
            navigationBarBackground,
            navigationBarButton,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private static var blueskyColoredItems: [Item] {
        let accentColor = UIColor(hex: 0x30AAF2)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(.accent, set: .init(accentColor))
        let background = Item(.background, set: .init(backgroundColor))
        let disabled = Item(.disabled, set: .init(.systemGray3))
        let groupedContentBackground = Item(.groupedContentBackground, set: .init(.init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(.navigationBarBackground, set: .init(backgroundColor))
        let navigationBarTitle = Item(.navigationBarTitle, set: .init(.white))
        let navigationBarButton = Item(.navigationBarButton, set: .init(accentColor))

        let senderBubble = Item(.senderBubble, set: .init(accentColor))
        let receiverBubble = Item(.receiverBubble, set: .init(.init(hex: 0x27252A)))

        let titleText = Item(.titleText, set: .init(.white))
        let subtitleText = Item(.subtitleText, set: .init(.lightGray))

        return [
            accent,
            background,
            disabled,
            groupedContentBackground,
            navigationBarBackground,
            navigationBarButton,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private static var duskColoredItems: [Item] {
        let accentColor = UIColor(hex: 0xFA8231)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(.accent, set: .init(accentColor))
        let background = Item(.background, set: .init(backgroundColor))
        let disabled = Item(.disabled, set: .init(.systemGray3))
        let groupedContentBackground = Item(.groupedContentBackground, set: .init(.init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(.navigationBarBackground, set: .init(backgroundColor))
        let navigationBarTitle = Item(.navigationBarTitle, set: .init(.white))
        let navigationBarButton = Item(.navigationBarButton, set: .init(accentColor))

        let senderBubble = Item(.senderBubble, set: .init(accentColor))
        let receiverBubble = Item(.receiverBubble, set: .init(.init(hex: 0x27252A)))

        let titleText = Item(.titleText, set: .init(.white))
        let subtitleText = Item(.subtitleText, set: .init(.lightGray))

        return [
            accent,
            background,
            disabled,
            groupedContentBackground,
            navigationBarBackground,
            navigationBarButton,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private static var firebrandColoredItems: [Item] {
        let accentColor = UIColor(hex: 0xFF5252)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(.accent, set: .init(accentColor))
        let background = Item(.background, set: .init(backgroundColor))
        let disabled = Item(.disabled, set: .init(.systemGray3))
        let groupedContentBackground = Item(.groupedContentBackground, set: .init(.init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(.navigationBarBackground, set: .init(backgroundColor))
        let navigationBarTitle = Item(.navigationBarTitle, set: .init(.white))
        let navigationBarButton = Item(.navigationBarButton, set: .init(accentColor))

        let senderBubble = Item(.senderBubble, set: .init(accentColor))
        let receiverBubble = Item(.receiverBubble, set: .init(.init(hex: 0x27252A)))

        let titleText = Item(.titleText, set: .init(.white))
        let subtitleText = Item(.subtitleText, set: .init(.lightGray))

        return [
            accent,
            background,
            disabled,
            groupedContentBackground,
            navigationBarBackground,
            navigationBarButton,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private static var prevaricationModeColoredItems: [Item] {
        let accentColor = UIColor(hex: 0x30AAF2) // Bluesky accent
        let senderBubbleColor = accentColor
        // let senderBubbleColor = UIColor(hex: 0xC7FFC4) // WhatsApp

        let accent = Item(.accent, set: .init(accentColor))
        let background = Item(.background, set: .init(.white))
        let disabled = Item(.disabled, set: .init(.systemGray))
        let groupedContentBackground = Item(.groupedContentBackground, set: .init(.init(hex: 0xF2F2F7)))

        let navigationBarBackground = Item(.navigationBarBackground, set: .init(accentColor))
        let navigationBarTitle = Item(.navigationBarTitle, set: .init(.white))
        let navigationBarButton = Item(
            .navigationBarButton,
            set: .init(UIApplication.isFullyV26Compatible ? .black : .white)
        )

        let senderBubble = Item(.senderBubble, set: .init(senderBubbleColor))
        let receiverBubble = Item(.receiverBubble, set: .init(.init(hex: 0xF8F8F8)))

        let titleText = Item(.titleText, set: .init(.black))
        let subtitleText = Item(.subtitleText, set: .init(.gray))

        return [
            accent,
            background,
            disabled,
            groupedContentBackground,
            navigationBarBackground,
            navigationBarButton,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private static var twilightColoredItems: [Item] {
        let accentColor = UIColor(hex: 0x786DC4)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(.accent, set: .init(accentColor))
        let background = Item(.background, set: .init(backgroundColor))
        let disabled = Item(.disabled, set: .init(.systemGray3))
        let groupedContentBackground = Item(.groupedContentBackground, set: .init(.init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(.navigationBarBackground, set: .init(backgroundColor))
        let navigationBarTitle = Item(.navigationBarTitle, set: .init(.white))
        let navigationBarButton = Item(.navigationBarButton, set: .init(accentColor))

        let senderBubble = Item(.senderBubble, set: .init(accentColor))
        let receiverBubble = Item(.receiverBubble, set: .init(.init(hex: 0x27252A)))

        let titleText = Item(.titleText, set: .init(.white))
        let subtitleText = Item(.subtitleText, set: .init(.lightGray))

        return [
            accent,
            background,
            disabled,
            groupedContentBackground,
            navigationBarBackground,
            navigationBarButton,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }
}

public extension ThemeService {
    static var isAppDefaultThemeApplied: Bool { currentTheme == UITheme.appDefault || currentTheme == UITheme.prevaricationMode }
}
