//
//  AppConstants+RecipientBarLayoutService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum RecipientBarLayoutService {
        public static let borderHeight: CGFloat = 0.3
        public static let frameHeight: CGFloat = 54

        public static let lightBackgroundColorAlphaComponent: CGFloat = 0.98
        public static let selectContactButtonXOriginDecrement: CGFloat = 10

        public static let textFieldWidthDecrement: CGFloat = 85
        public static let textFieldXOriginIncrement: CGFloat = 5

        public static let toLabelFontSize: CGFloat = 14
        public static let toLabelXOrigin: CGFloat = 15
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum RecipientBarLayoutService {
        public static let darkBorder: Color = .init(uiColor: .init(hex: 0x3C3C_434A))
        public static let lightBorder: Color = .init(uiColor: .init(hex: 0xDCDCDD))

        public static let lightBackground: Color = .init(uiColor: .white)
        public static let toLabelText: Color = .init(uiColor: .gray)
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum RecipientBarLayoutService {
        public static let recipientBarSemanticTag = "RECIPIENT_BAR"
        public static let selectContactButtonSemanticTag = "SELECT_CONTACT_BUTTON"

        public static let tableViewCellReuseIdentifier = "contactCell"
        public static let tableViewSemanticTag = "TABLE_VIEW"

        public static let textFieldSemanticTag = "TEXT_FIELD"

        public static let toLabelFontName = "SFUIText-Regular"
        public static let toLabelSemanticTag = "TO_LABEL"
    }
}
