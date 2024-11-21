//
//  AppThemes.swift
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
public extension AppTheme {
    // MARK: - Type Aliases

    private typealias Item = UITheme.ColoredItem

    // MARK: - Types

    struct List: AppSubsystem.Delegates.AppThemeListDelegate {
        public var allAppThemes: [AppTheme] {
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

    static let appDefault: AppTheme = .init(.init(name: "Default", items: appDefaultColoredItems))
    static let bluesky: AppTheme = .init(.init(name: "Bluesky", items: blueskyColoredItems, style: .dark))
    static let dusk: AppTheme = .init(.init(name: "Dusk", items: duskColoredItems, style: .dark))
    static let firebrand: AppTheme = .init(.init(name: "Firebrand", items: firebrandColoredItems, style: .dark))
    static let prevaricationMode: AppTheme = .init(.init(name: "Prevarication Mode", items: prevaricationModeColoredItems, style: .light))
    static let twilight: AppTheme = .init(.init(name: "Twilight", items: twilightColoredItems, style: .dark))

    // MARK: - Colored Items

    private static var appDefaultColoredItems: [Item] {
        let accentColor = UIColor.systemBlue

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: .white, variant: .black))
        let disabled = Item(type: .disabled, set: .init(primary: .systemGray3))
        let listViewBackground = Item(type: .listViewBackground, set: .init(primary: .init(hex: 0xF2F2F7), variant: .init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(type: .navigationBarBackground, set: .init(primary: .init(hex: 0xF8F8F8), variant: .init(hex: 0x2A2A2C)))
        let navigationBarTitle = Item(type: .navigationBarTitle, set: .init(primary: .black, variant: .white))

        let senderBubble = Item(type: .senderBubble, set: .init(primary: accentColor))
        let receiverBubble = Item(type: .receiverBubble, set: .init(primary: .init(hex: 0xE5E5EA), variant: .init(hex: 0x27252A)))

        let titleText = Item(type: .titleText, set: .init(primary: .black, variant: .white))
        let subtitleText = Item(type: .subtitleText, set: .init(primary: .gray))

        return [
            accent,
            background,
            disabled,
            listViewBackground,
            navigationBarBackground,
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

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
        let disabled = Item(type: .disabled, set: .init(primary: .systemGray3))
        let listViewBackground = Item(type: .listViewBackground, set: .init(primary: .init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(type: .navigationBarBackground, set: .init(primary: backgroundColor))
        let navigationBarTitle = Item(type: .navigationBarTitle, set: .init(primary: accentColor))

        let senderBubble = Item(type: .senderBubble, set: .init(primary: accentColor))
        let receiverBubble = Item(type: .receiverBubble, set: .init(primary: .init(hex: 0x27252A)))

        let titleText = Item(type: .titleText, set: .init(primary: .white))
        let subtitleText = Item(type: .subtitleText, set: .init(primary: .lightGray))

        return [
            accent,
            background,
            disabled,
            listViewBackground,
            navigationBarBackground,
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

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
        let disabled = Item(type: .disabled, set: .init(primary: .systemGray3))
        let listViewBackground = Item(type: .listViewBackground, set: .init(primary: .init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(type: .navigationBarBackground, set: .init(primary: backgroundColor))
        let navigationBarTitle = Item(type: .navigationBarTitle, set: .init(primary: accentColor))

        let senderBubble = Item(type: .senderBubble, set: .init(primary: accentColor))
        let receiverBubble = Item(type: .receiverBubble, set: .init(primary: .init(hex: 0x27252A)))

        let titleText = Item(type: .titleText, set: .init(primary: .white))
        let subtitleText = Item(type: .subtitleText, set: .init(primary: .lightGray))

        return [
            accent,
            background,
            disabled,
            listViewBackground,
            navigationBarBackground,
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

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
        let disabled = Item(type: .disabled, set: .init(primary: .systemGray3))
        let listViewBackground = Item(type: .listViewBackground, set: .init(primary: .init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(type: .navigationBarBackground, set: .init(primary: backgroundColor))
        let navigationBarTitle = Item(type: .navigationBarTitle, set: .init(primary: accentColor))

        let senderBubble = Item(type: .senderBubble, set: .init(primary: accentColor))
        let receiverBubble = Item(type: .receiverBubble, set: .init(primary: .init(hex: 0x27252A)))

        let titleText = Item(type: .titleText, set: .init(primary: .white))
        let subtitleText = Item(type: .subtitleText, set: .init(primary: .lightGray))

        return [
            accent,
            background,
            disabled,
            listViewBackground,
            navigationBarBackground,
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

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: .white))
        let disabled = Item(type: .disabled, set: .init(primary: .systemGray))
        let listViewBackground = Item(type: .listViewBackground, set: .init(primary: .init(hex: 0xF2F2F7)))

        let navigationBarBackground = Item(type: .navigationBarBackground, set: .init(primary: accentColor))
        let navigationBarTitle = Item(type: .navigationBarTitle, set: .init(primary: .white))

        let senderBubble = Item(type: .senderBubble, set: .init(primary: senderBubbleColor))
        let receiverBubble = Item(type: .receiverBubble, set: .init(primary: .init(hex: 0xF8F8F8)))

        let titleText = Item(type: .titleText, set: .init(primary: .black))
        let subtitleText = Item(type: .subtitleText, set: .init(primary: .gray))

        return [
            accent,
            background,
            disabled,
            listViewBackground,
            navigationBarBackground,
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

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
        let disabled = Item(type: .disabled, set: .init(primary: .systemGray3))
        let listViewBackground = Item(type: .listViewBackground, set: .init(primary: .init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(type: .navigationBarBackground, set: .init(primary: backgroundColor))
        let navigationBarTitle = Item(type: .navigationBarTitle, set: .init(primary: accentColor))

        let senderBubble = Item(type: .senderBubble, set: .init(primary: accentColor))
        let receiverBubble = Item(type: .receiverBubble, set: .init(primary: .init(hex: 0x27252A)))

        let titleText = Item(type: .titleText, set: .init(primary: .white))
        let subtitleText = Item(type: .subtitleText, set: .init(primary: .lightGray))

        return [
            accent,
            background,
            disabled,
            listViewBackground,
            navigationBarBackground,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }
}

public extension ThemeService {
    static var isAppDefaultThemeApplied: Bool { currentTheme == AppTheme.appDefault.theme || currentTheme == AppTheme.prevaricationMode.theme }
}
