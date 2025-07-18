//
//  AppConstants+RecipientBarService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats.ChatPageViewService {
    enum RecipientBarService {
        enum ActionHandler {
            public static let becomeFirstResponderDelayMilliseconds: CGFloat = 10
            public static let presentContactCTADelayMilliseconds: CGFloat = 500
            public static let sublevelCount: CGFloat = 10
        }

        enum Config {
            public static let initialLevelMaxY: CGFloat = 42

            // swiftlint:disable identifier_name
            public static let textFieldReconfigurationInitialLevelWidthDecrement: CGFloat = 40
            public static let textFieldReconfigurationNotInitialLevelWidthDecrement: CGFloat = 10

            public static let textFieldReconfigurationXOriginIncrement: CGFloat = 4
            // swiftlint:enable identifier_name

            public static let sublevelMultiplier: CGFloat = 32
        }

        enum ContactSelectionUI {
            public static let adjacentViewSpacing: CGFloat = 2

            public static let contactLabelSystemFontSize: CGFloat = 16

            public static let contactViewCornerRadius: CGFloat = UIApplication.v26FeaturesEnabled ? 12 : 6
            public static let contactViewFrameHeight: CGFloat = 30
            public static let contactViewFrameXOrigin: CGFloat = 40
            public static let contactViewMaximumWidthDivisor: CGFloat = 2
            public static let contactViewWidthIncrement: CGFloat = 10
            public static let contactViewXOriginIncrement: CGFloat = 5

            public static let labelRepresentationAnimationDuration: CGFloat = 0.3

            public static let recipientBarMaxXDecrement: CGFloat = 60
            public static let recipientBarReconfigurationSublevel: CGFloat = 2

            public static let selectedContactPairsMaximum: CGFloat = 10
            public static let sublevelCount: CGFloat = 10

            public static let v26ContactViewAlpha: CGFloat = 0.85
        }

        enum Layout {
            public static let borderHeight: CGFloat = 0.3

            public static let frameHeight: CGFloat = 54

            public static let glassEffectViewAlpha: CGFloat = 0.95
            public static let glassEffectViewCornerRadius: CGFloat = 28

            public static let lightBackgroundColorAlphaComponent: CGFloat = 0.98

            public static let selectContactButtonMinXDecrement: CGFloat = 5
            public static let selectContactButtonXOriginDecrement: CGFloat = UIApplication.v26FeaturesEnabled ? 40 : 10
            public static let selectContactButtonFrameHeight: CGFloat = UIApplication.v26FeaturesEnabled ? 22 : 26
            public static let selectContactButtonFrameWidth: CGFloat = UIApplication.v26FeaturesEnabled ? 22 : 26

            public static let textFieldWidthDecrement: CGFloat = 85
            public static let textFieldXOriginIncrement: CGFloat = 5
            public static let toLabelFontSize: CGFloat = 14
            public static let toLabelXOrigin: CGFloat = 15

            public static let v26FrameWidthDecrement: CGFloat = 50
            public static let v26TextFieldFrameHeight: CGFloat = 24
            public static let v26YOriginIncrement: CGFloat = 10
        }

        enum UITextFieldDelegate { // swiftlint:disable:next identifier_name
            public static let toggleLabelRepresentationDelayMilliseconds: CGFloat = 10
        }
    }
}

// MARK: - Color

public extension AppConstants.Colors.ChatPageViewService {
    enum RecipientBarService {
        enum ContactSelectionUI {
            public static let accent: Color = .init(uiColor: .systemBlue)

            public static let contactViewDarkSelection: Color = .init(uiColor: .init(hex: 0x2A2A2C))
            public static let contactViewHighlightedText: Color = .init(uiColor: .white)
            public static let contactViewLightSelection: Color = .init(uiColor: .init(hex: 0xECF0F1))
            public static let contactViewRedText: Color = .init(uiColor: .systemGreen)

            public static let labelRepresentationColor: Color = .init(uiColor: .clear)
        }

        enum Layout {
            public static let darkBorder: Color = .init(uiColor: .init(hex: 0x3C3C_434A))
            public static let lightBorder: Color = .init(uiColor: .init(hex: 0xDCDCDD))

            public static let lightBackground: Color = .init(uiColor: Application.isInPrevaricationMode ? .init(hex: 0xF8F8F8) : .white)
            public static let toLabelText: Color = .init(uiColor: .gray)
        }
    }
}

// MARK: - String

public extension AppConstants.Strings.ChatPageViewService {
    enum RecipientBarService {
        enum ContactSelectionUI {
            public static let contactLabelSemanticTag = "CONTACT_LABEL"
            public static let contactViewSemanticTag = "CONTACT_VIEW"
        }

        enum Layout {
            public static let glassEffectViewSemanticTag = "GLASS_EFFECT_VIEW" // swiftlint:disable:next identifier_name
            public static let prevaricationModeSelectContactButtonImageSystemName = "person.crop.circle.fill.badge.plus"
            public static let recipientBarSemanticTag = "RECIPIENT_BAR"
            public static let selectContactButtonSemanticTag = "SELECT_CONTACT_BUTTON"

            public static let tableViewCellReuseIdentifier = "contactCell"
            public static let tableViewSemanticTag = "TABLE_VIEW"

            public static let textFieldSemanticTag = "TEXT_FIELD"

            public static let toLabelFontName = "SFUIText-Regular"
            public static let toLabelSemanticTag = "TO_LABEL"
        }
    }
}
