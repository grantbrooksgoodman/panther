//
//  AppConstants+ChatParticipantView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ChatParticipantView {
        public static let avatarImageViewSizeHeight: CGFloat = 40
        public static let avatarImageViewSizeWidth: CGFloat = 40
        public static let avatarImageViewTrailingPadding: CGFloat = 2
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ChatParticipantView {
        public static let deleteButtonTint: Color = .red // swiftlint:disable:next identifier_name
        public static let penPalsSharingStatusIconCompleteForeground: Color = .green // swiftlint:disable:next identifier_name
        public static let penPalsSharingStatusIconIncompleteForeground: Color = .orange
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ChatParticipantView {
        public static let deleteButtonImageSystemName = "trash" // swiftlint:disable:next identifier_name
        public static let penPalsSharingStatusIconCompleteImageSystemName = "person.crop.circle.fill.badge.checkmark" // swiftlint:disable:next identifier_name
        public static let penPalsSharingStatusIconIncompleteImageSystemName = "person.crop.circle.badge.questionmark.fill"
    }
}
