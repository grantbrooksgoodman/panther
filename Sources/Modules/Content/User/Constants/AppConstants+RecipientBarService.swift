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

extension AppConstants.CGFloats.ChatPageViewService {
    enum RecipientBarService {
        enum ActionHandler {
            static let becomeFirstResponderDelayMilliseconds: CGFloat = 10
            static let presentContactCTADelayMilliseconds: CGFloat = 500
            static let sublevelCount: CGFloat = 10
        }

        enum Config {
            static let initialLevelMaxY: CGFloat = 42

            // swiftlint:disable identifier_name
            static let textFieldReconfigurationInitialLevelWidthDecrement: CGFloat = 40
            static let textFieldReconfigurationNotInitialLevelWidthDecrement: CGFloat = 10

            static let textFieldReconfigurationXOriginIncrement: CGFloat = 4
            // swiftlint:enable identifier_name

            static let sublevelMultiplier: CGFloat = 32
        }

        enum ContactSelectionUI {
            static let adjacentViewSpacing: CGFloat = 2

            static let contactLabelSystemFontSize: CGFloat = 16

            static let contactViewCornerRadius: CGFloat = UIApplication.isFullyV26Compatible ? 12 : 6
            static let contactViewFrameHeight: CGFloat = 30
            static let contactViewFrameXOrigin: CGFloat = 40
            static let contactViewMaximumWidthDivisor: CGFloat = 2
            static let contactViewWidthIncrement: CGFloat = 10
            static let contactViewXOriginIncrement: CGFloat = 5

            static let labelRepresentationAnimationDuration: CGFloat = 0.3

            static let recipientBarMaxXDecrement: CGFloat = 60
            static let recipientBarReconfigurationSublevel: CGFloat = 2

            static let selectedContactPairsMaximum: CGFloat = 10
            static let sublevelCount: CGFloat = 10

            static let v26ContactViewAlpha: CGFloat = 0.85
        }

        enum Layout {
            static let borderHeight: CGFloat = 0.3

            static let frameHeight: CGFloat = 54

            static let glassEffectViewAlpha: CGFloat = 0.95
            static let glassEffectViewCornerRadius: CGFloat = 28

            static let lightBackgroundColorAlphaComponent: CGFloat = 0.98

            static let selectContactButtonMinXDecrement: CGFloat = 5
            static let selectContactButtonXOriginDecrement: CGFloat = UIApplication.isFullyV26Compatible ? 40 : 10
            static let selectContactButtonFrameHeight: CGFloat = UIApplication.isFullyV26Compatible ? 22 : 26
            static let selectContactButtonFrameWidth: CGFloat = UIApplication.isFullyV26Compatible ? 22 : 26

            static let textFieldWidthDecrement: CGFloat = 85
            static let textFieldXOriginIncrement: CGFloat = 5
            static let toLabelFontSize: CGFloat = 14
            static let toLabelXOrigin: CGFloat = 15

            static let v26FrameWidthDecrement: CGFloat = 50
            static let v26TextFieldFrameHeight: CGFloat = 24
            static let v26YOriginIncrement: CGFloat = 10
        }

        enum UITextFieldDelegate { // swiftlint:disable:next identifier_name
            static let toggleLabelRepresentationDelayMilliseconds: CGFloat = 10
        }
    }
}

// MARK: - Color

extension AppConstants.Colors.ChatPageViewService {
    enum RecipientBarService {
        enum ContactSelectionUI {
            static let accent: Color = .init(uiColor: .systemBlue)

            static let contactViewDarkSelection: Color = .init(uiColor: .init(hex: 0x2A2A2C))
            static let contactViewHighlightedText: Color = .init(uiColor: .white)
            static let contactViewLightSelection: Color = .init(uiColor: .init(hex: 0xECF0F1))
            static let contactViewRedText: Color = .init(uiColor: .systemGreen)

            static let labelRepresentationColor: Color = .init(uiColor: .clear)
        }

        enum Layout {
            static let darkBorder: Color = .init(uiColor: .init(hex: 0x3C3C_434A))
            static let lightBorder: Color = .init(uiColor: .init(hex: 0xDCDCDD))

            static let lightBackground: Color = .init(uiColor: Application.isInPrevaricationMode ? .init(hex: 0xF8F8F8) : .white)
            static let toLabelText: Color = .init(uiColor: .gray)
        }
    }
}

// MARK: - String

extension AppConstants.Strings.ChatPageViewService {
    enum RecipientBarService {
        enum ContactSelectionUI {
            static let contactLabelSemanticTag = "CONTACT_LABEL"
            static let contactViewSemanticTag = "CONTACT_VIEW"
        }

        enum Layout {
            static let glassEffectViewSemanticTag = "GLASS_EFFECT_VIEW" // swiftlint:disable:next identifier_name
            static let prevaricationModeSelectContactButtonImageSystemName = "person.crop.circle.fill.badge.plus"
            static let recipientBarSemanticTag = "RECIPIENT_BAR"
            static let selectContactButtonSemanticTag = "SELECT_CONTACT_BUTTON"

            static let tableViewCellReuseIdentifier = "contactCell"
            static let tableViewSemanticTag = "TABLE_VIEW"

            static let textFieldSemanticTag = "TEXT_FIELD"

            static let toLabelFontName = "SFUIText-Regular"
            static let toLabelSemanticTag = "TO_LABEL"
        }
    }
}
