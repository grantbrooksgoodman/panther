//
//  AppConstants+ChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// swiftlint:disable identifier_name

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ChatPageView {
        public static let dataSourceAudioCellProgressViewDefaultThemeTrackTintColorAlphaComponent: CGFloat = 0.8
        public static let dataSourceAudioCellProgressViewDefaultThemeTrackTintColorDarkeningPercentage: CGFloat = 6

        public static let dataSourceMessageTopLabelAttributedTextAttributesFontSize: CGFloat = 10.5

        public static let displayDelegateMessageStyleCustomLayerCornerRadius: CGFloat = 10

        public static let layoutDelegateCellBottomLabelHeight: CGFloat = 5
        public static let layoutDelegateCellTopLabelHeight: CGFloat = 25
        public static let layoutDelegateCellTopLabelHeightSentDateSecondsComparator: CGFloat = 5400
        public static let layoutDelegateMessageTopLabelHeight: CGFloat = 15

        public static let messageOutgoingCellBottomLabelAlignmentRightTextInset: CGFloat = 10
        public static let messageOutgoingCellBottomLabelAlignmentTopTextInset: CGFloat = 2

        public static let messageSeparatorAttributedDateStringBoldAttributesSystemFontSize: CGFloat = 12
        public static let messageSeparatorAttributedDateStringStandardAttributesSystemFontSize: CGFloat = 12

        public static let messageSeparatorAttributedDateStringUnderYearPrimaryComparator: CGFloat = -604_800
        public static let messageSeparatorAttributedDateStringUnderYearSecondaryComparator: CGFloat = -31_540_000
        public static let messageSeparatorAttributedDateStringWeekdayComparator: CGFloat = -604_800
        public static let messageSeparatorAttributedDateStringYesterdayComparator: CGFloat = -86400

        public static let textCellMessageLabelLeftTextInset: CGFloat = 15
        public static let textCellMessageLabelRightTextInset: CGFloat = 1
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ChatPageView {
        public static let dataSourceCurrentUserAudioTintColor: Color = .init(uiColor: .white)
        public static let dataSourceMessageTopLabelAttributedTextAttributesForeground: Color = .init(uiColor: .systemGray)

        public static let displayDelegateDetectorAttributesAlternateForeground: Color = .init(uiColor: .black)
        public static let displayDelegateDetectorAttributesPrimaryForeground: Color = .init(uiColor: .white)

        public static let displayDelegateGenericAvatarViewBackground: Color = .init(uiColor: .clear)
        public static let displayDelegateGenericAvatarViewTint: Color = .init(uiColor: .gray)

        public static let messageSeparatorAttributedDateStringBoldAttributesForeground: Color = .init(uiColor: .gray)
        public static let messageSeparatorAttributedDateStringStandardAttributesForeground: Color = .init(uiColor: .lightGray)
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ChatPageView {
        public static let cellDelegateDateSelectionURLString = "calshow:"
        public static let cellDelegatePhoneNumberSelectionURLString = "tel://"

        public static let dataSourceMessageTopLabelAttributedTextAttributesFontName = "SFUIText-Regular"

        public static let displayDelegateGenericAvatarViewImageName = "Contact.png"
    }
}

// swiftlint:enable identifier_name
