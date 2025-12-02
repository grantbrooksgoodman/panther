//
//  AppConstants+ChatInfoPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ChatInfoPageView {
        static let addContactButtonCircleFrameMaxHeight: CGFloat = 40
        static let addContactButtonCircleFrameMaxWidth: CGFloat = 40
        static let addContactButtonCircleTrailingPadding: CGFloat = 2

        static let addContactButtonImageHeight: CGFloat = 15
        static let addContactButtonImageWidth: CGFloat = 15

        static let avatarImageViewHorizontalPadding: CGFloat = 10
        static let avatarImageViewSizeHeight: CGFloat = 100
        static let avatarImageViewSizeWidth: CGFloat = 100
        static let avatarImageViewTopPadding: CGFloat = 20

        static let changeMetadataButtonHorizontalPadding: CGFloat = 10
        static let changeMetadataButtonLabelFontSize: CGFloat = 15

        static let chatInfoCellSubtitleLabelFontSize: CGFloat = 15
        static let chatTitleLabelHorizontalPadding: CGFloat = 10

        // swiftlint:disable:next identifier_name
        static let leaveConversationListRowViewHorizontalPadding: CGFloat = 20
        static let listTransitionAnimationDuration: CGFloat = 0.2
        static let listViewYOffset: CGFloat = -8
        static let listViewAlternateYOffset: CGFloat = -30

        static let penPalsListRowViewHorizontalPadding: CGFloat = 30
        static let penPalsListRowViewTopPadding: CGFloat = 5

        // swiftlint:disable:next identifier_name
        static let segmentedControlHorizontalOrLeadingPadding: CGFloat = 20
        static let segmentedControlTopPadding: CGFloat = 20
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ChatInfoPageView {
        static let addContactButtonCircleDarkForeground: Color = .init(uiColor: .init(hex: 0x3A3A3C))
        static let addContactButtonCircleLightForeground: Color = .init(uiColor: .init(hex: 0xE5E5EA))

        static let addContactButtonLabelForeground: Color = .init(uiColor: .accentOrSystemBlue)
        static let addContactButtonSymbolForeground: Color = .init(uiColor: .accentOrSystemBlue)

        static let changeMetadataButtonForeground: Color = .init(uiColor: .accentOrSystemBlue)
        static let leaveConversationListRowViewForeground: Color = .red
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatInfoPageView {
        static let addContactButtonImageSystemName = "plus"
        static let doneButtonImageSystemName = "checkmark"
    }
}
