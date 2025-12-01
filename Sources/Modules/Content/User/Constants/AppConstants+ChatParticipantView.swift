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

extension AppConstants.CGFloats {
    enum ChatParticipantView {
        static let avatarImageViewSizeHeight: CGFloat = 40
        static let avatarImageViewSizeWidth: CGFloat = 40
        static let avatarImageViewTrailingPadding: CGFloat = 2
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ChatParticipantView {
        static let deleteButtonTint: Color = .red // swiftlint:disable:next identifier_name
        static let penPalsSharingStatusIconCompleteForeground: Color = .green // swiftlint:disable:next identifier_name
        static let penPalsSharingStatusIconIncompleteForeground: Color = .orange
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatParticipantView {
        static let deleteButtonImageSystemName = "trash" // swiftlint:disable:next identifier_name
        static let penPalsSharingStatusIconCompleteImageSystemName = "person.crop.circle.fill.badge.checkmark" // swiftlint:disable:next identifier_name
        static let penPalsSharingStatusIconIncompleteImageSystemName = "person.crop.circle.badge.questionmark.fill"
    }
}
