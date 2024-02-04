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

        public static let dataSourceCellBottomLabelAttributedTextBoldAttributesSystemFontSize: CGFloat = 12
        public static let dataSourceCellBottomLabelAttributedTextStandardAttributesSystemFontSize: CGFloat = 12

        public static let dataSourceMessageTopLabelAttributedTextAttributesFontSize: CGFloat = 10.5

        public static let deliveryProgressAnimationDelay: CGFloat = 1
        public static let deliveryProgressAnimationDuration: CGFloat = 0.2

        public static let deliveryProgressTimerProgressIncrement: CGFloat = 0.001
        public static let deliveryProgressTimerProgressIncrementThreshold: CGFloat = 0.9

        public static let deliveryProgressTimerTimeInterval: CGFloat = 0.01
        public static let deliveryProgressViewFrameHeight: CGFloat = 2

        public static let displayDelegateMessageStyleCustomLayerCornerRadius: CGFloat = 10

        public static let inputBarLayerBorderWidth: CGFloat = 0.5
        public static let inputBarLayerCornerRadius: CGFloat = 15

        public static let inputBarSendButtonOnSelectedTransformScaleX: CGFloat = 1.1
        public static let inputBarSendButtonOnSelectedTransformScaleY: CGFloat = 1.1

        public static let inputBarSendButtonSizeHeight: CGFloat = 30
        public static let inputBarSendButtonSizeWidth: CGFloat = 30

        public static let inputBarTransitionAnimationDuration: CGFloat = 0.3

        public static let layoutDelegateCellBottomLabelHeight: CGFloat = 20
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

        public static let typingIndicatorTimerTimeInterval: CGFloat = 3
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ChatPageView {
        public static let cellDelegateAudioMessageCellCurrentUserProgressViewTint: Color = .init(uiColor: .white)

        public static let dataSourceCellBottomLabelAttributedTextBoldAttributesForeground: Color = .init(uiColor: .gray)
        public static let dataSourceCellBottomLabelAttributedTextStandardAttributesForeground: Color = .init(uiColor: .lightGray)

        public static let dataSourceCurrentUserAudioTintColor: Color = .init(uiColor: .white)
        public static let dataSourceMessageTopLabelAttributedTextAttributesForeground: Color = .init(uiColor: .systemGray)

        public static let displayDelegateDetectorAttributesAlternateForeground: Color = .init(uiColor: .black)
        public static let displayDelegateDetectorAttributesPrimaryForeground: Color = .init(uiColor: .white)

        public static let displayDelegateGenericAvatarViewBackground: Color = .init(uiColor: .clear)
        public static let displayDelegateGenericAvatarViewTint: Color = .init(uiColor: .gray)

        public static let inputBarContentViewRecordLayerBorder: Color = .init(uiColor: .clear)
        public static let inputBarContentViewTextLayerBorder: Color = .init(uiColor: .systemGray)

        public static let inputBarInputTextViewRecordLayerBorder: Color = .init(uiColor: .systemGray)
        public static let inputBarInputTextViewTextLayerBorder: Color = .init(uiColor: .clear)

        public static let inputBarInputTextViewTint: Color = .init(uiColor: .clear)

        public static let inputBarSendButtonRecordTint: Color = .init(uiColor: .red)
        public static let inputBarSendButtonTextTint: Color = .init(uiColor: .systemBlue)

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

        public static let deliveryProgressViewSemanticTag = "DELIVERY_PROGRESS_VIEW"

        public static let displayDelegateGenericAvatarViewImageName = "Contact.png"

        public static let sendButtonAlternateDefaultImageName = "Send (Alternate).png"
        public static let sendButtonAlternateHighlightedImageName = "Send (Alternate - Highlighted).png"

        public static let sendButtonPrimaryDefaultImageName = "Send.png"
        public static let sendButtonPrimaryHighlightedImageName = "Send (Highlighted).png"

        public static let recordButtonDefaultImageName = "Record.png"
        public static let recordButtonHighlightedImageName = "Record (Highlighted).png"

        public static let recordButtonSemanticTag = "RECORD_BUTTON"
        public static let sendButtonSemanticTag = "SEND_BUTTON"
    }
}

// swiftlint:enable identifier_name
