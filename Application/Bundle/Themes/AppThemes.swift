//
//  AppThemes.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/**
 Use this enum to build new `UITheme`s.
 */
public enum AppTheme: CaseIterable {
    // MARK: - Type Aliases

    private typealias Item = UITheme.ColoredItem

    // MARK: - Cases

    case `default`
    case bluesky
    case dusk
    case firebrand
    case twilight

    // MARK: - Properties

    public var theme: UITheme {
        switch self {
        case .default:
            return .init(name: "Default", items: defaultColoredItems)

        case .bluesky:
            return .init(name: "Bluesky", items: blueskyColoredItems, style: .dark)

        case .dusk:
            return .init(name: "Dusk", items: duskColoredItems, style: .dark)

        case .firebrand:
            return .init(name: "Firebrand", items: firebrandColoredItems, style: .dark)

        case .twilight:
            return .init(name: "Twilight", items: twilightColoredItems, style: .dark)
        }
    }

    // MARK: - Colored Item Accessors

    private var defaultColoredItems: [Item] {
        let accentColor = UIColor.systemBlue

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: .white, variant: .black))
        let listViewBackground = Item(type: .listViewBackground, set: .init(primary: .init(hex: 0xF2F2F7), variant: .init(hex: 0x1C1C1E)))

        let navigationBarBackground = Item(type: .navigationBarBackground, set: .init(primary: .init(hex: 0xF8F8F8), variant: .init(hex: 0x2A2A2C)))
        let navigationBarTitle = Item(type: .navigationBarTitle, set: .init(primary: .black, variant: .white))

        let senderBubble = Item(type: .senderBubble, set: .init(primary: accentColor))
        let receiverBubble = Item(type: .receiverBubble, set: .init(primary: .init(hex: 0xE5E5EA), variant: .init(hex: 0x27252A)))

        let titleText = Item(type: .titleText, set: .init(primary: .black, variant: .white))
        let subtitleText = Item(type: .subtitleText, set: .init(primary: .black, variant: .white))

        return [
            accent,
            background,
            listViewBackground,
            navigationBarBackground,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private var blueskyColoredItems: [Item] {
        let accentColor = UIColor(hex: 0x30AAF2)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
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
            listViewBackground,
            navigationBarBackground,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private var duskColoredItems: [Item] {
        let accentColor = UIColor(hex: 0xFA8231)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
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
            listViewBackground,
            navigationBarBackground,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private var firebrandColoredItems: [Item] {
        let accentColor = UIColor(hex: 0xFF5252)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
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
            listViewBackground,
            navigationBarBackground,
            navigationBarTitle,
            senderBubble,
            receiverBubble,
            titleText,
            subtitleText,
        ]
    }

    private var twilightColoredItems: [Item] {
        let accentColor = UIColor(hex: 0x786DC4)
        let backgroundColor = UIColor(hex: 0x1A1A1A)

        let accent = Item(type: .accent, set: .init(primary: accentColor))
        let background = Item(type: .background, set: .init(primary: backgroundColor))
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
