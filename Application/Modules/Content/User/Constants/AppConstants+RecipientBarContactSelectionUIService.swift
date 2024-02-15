//
//  AppConstants+RecipientBarContactSelectionUIService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum RecipientBarContactSelectionUIService {
        public static let adjacentViewSpacing: CGFloat = 2

        public static let becomeFirstResponderDelayMilliseconds: CGFloat = 10

        public static let contactLabelSystemFontSize: CGFloat = 16

        public static let contactViewCornerRadius: CGFloat = 6
        public static let contactViewFrameHeight: CGFloat = 30
        public static let contactViewFrameXOrigin: CGFloat = 40
        public static let contactViewMaximumWidthDivisor: CGFloat = 2
        public static let contactViewWidthIncrement: CGFloat = 10
        public static let contactViewXOriginIncrement: CGFloat = 5

        public static let initialLevelMaxY: CGFloat = 42

        public static let recipientBarMaxXDecrement: CGFloat = 60
        public static let recipientBarReconfigurationSublevel: CGFloat = 2

        public static let selectedContactPairsMaximum: CGFloat = 10

        public static let sublevelCount: CGFloat = 10
        public static let sublevelMultiplier: CGFloat = 32

        // swiftlint:disable identifier_name
        public static let textFieldReconfigurationInitialLevelWidthDecrement: CGFloat = 40
        public static let textFieldReconfigurationNotInitialLevelWidthDecrement: CGFloat = 10

        public static let textFieldReconfigurationXOriginIncrement: CGFloat = 4
        // swiftlint:enable identifier_name
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum RecipientBarContactSelectionUIService {
        public static let contactViewDarkSelection: Color = .init(uiColor: .init(hex: 0x2A2A2C))
        public static let contactViewHighlightedText: Color = .init(uiColor: .white)
        public static let contactViewLightSelection: Color = .init(uiColor: .init(hex: 0xECF0F1))
        public static let contactViewRedText: Color = .init(uiColor: .systemGreen)
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum RecipientBarContactSelectionUIService {
        public static let contactLabelSemanticTag = "CONTACT_LABEL"
        public static let contactViewSemanticTag = "CONTACT_VIEW"
    }
}
