//
//  AppConstants+ChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable identifier_name

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ChatPageView {
        static let messageLabelInset: CGFloat = 4

        static let messageOutgoingCellBottomLabelAlignmentRightTextInset: CGFloat = 10
        static let messageOutgoingCellBottomLabelAlignmentTopTextInset: CGFloat = 2

        static let textCellMessageLabelLeftTextInset: CGFloat = 15
        static let textCellMessageLabelRightTextInset: CGFloat = 1

        enum AVSpeechSynthesizerDelegate {
            static let attributedStringParagraphStyleLineSpacing: CGFloat = 1.25
        }

        enum FailedOutboxIndicator {
            static let indicatorButtonSize: CGFloat = 22
            static let indicatorButtonSpacing: CGFloat = 6
        }

        enum MessagesDataSource {
            static let cellBottomLabelAttributedTextBoldAttributesSystemFontSize: CGFloat = 12
            static let cellBottomLabelAttributedTextEmojiAttributesSystemFontSize: CGFloat = 14
            static let cellBottomLabelAttributedTextStandardAttributesSystemFontSize: CGFloat = 12

            static let messageTimestampLabelAttributedTextAttributesSystemFontSize: CGFloat = 12
            static let messageTopLabelAttributedTextAttributesBaselineOffset: CGFloat = 3
            static let messageTopLabelAttributedTextAttributesFontSize: CGFloat = 10.5
        }

        enum MessagesDisplayDelegate {
            static let audioCellProgressViewTrackTintColorAlphaComponent: CGFloat = 0.8
            static let audioCellProgressViewTrackTintColorDarkeningPercentage: CGFloat = 6

            static let messageStyleCustomLayerCornerRadius: CGFloat = 10
            static let messageStyleCustomLayerShadowOffsetHeight: CGFloat = 2
            static let messageStyleCustomLayerShadowOpacity: CGFloat = 0.1
            static let messageStyleCustomLayerShadowRadius: CGFloat = 4
        }

        enum MessagesLayoutDelegate {
            static let cellBottomLabelHeight: CGFloat = 20
            static let cellTopLabelHeight: CGFloat = 25
            static let cellTopLabelHeightSentDateSecondsComparator: CGFloat = 5400
            static let messageTopLabelHeight: CGFloat = 15
        }

        enum UITextViewDelegate {
            static let setButtonsIsEnabledDelayMilliseconds: CGFloat = 100
            static let toggleLabelRepresentationDelayMilliseconds: CGFloat = 10
        }
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ChatPageView {
        static let messagesCollectionViewPrevaricationModeBackground = Color(hex: 0xF3EDE6)

        enum AVSpeechSynthesizerDelegate {
            static let willSpeakRangeOfSpeechStringHighlight = Color(.red)
            static let willSpeakRangeOfSpeechStringNotWhite = Color(.black)
            static let willSpeakRangeOfSpeechStringWhite = Color(.white)
        }

        enum MessagesDataSource {
            static let cellBottomLabelAttributedTextBoldAttributesForeground = Color(.gray)
            static let cellBottomLabelAttributedTextStandardAttributesForeground = Color(.lightGray)

            static let currentUserAudioTintColor = Color(.white)

            static let messageTimestampLabelAttributedTextAttributesForeground = Color(.lightGray)
            static let messageTopLabelAttributedTextAttributesForeground = Color(.systemGray)
        }

        enum MessagesDisplayDelegate {
            static let audioCellProgressViewCurrentUserAccent = Color(.white)

            static let detectorAttributesAlternateForeground = Color(.black)
            static let detectorAttributesPrimaryForeground = Color(.white)

            static let genericAvatarViewBackground = Color(.clear)
            static let genericAvatarViewTint = Color(.gray)

            static let messageStyleCustomLayerShadowColor = Color(.black)

            static let penPalsAvatarViewBackground = Color(.clear)
            static let penPalsAvatarViewTint = Color(.purple)
        }
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatPageView {
        enum FailedOutboxIndicator {
            static let buttonImageSystemName = "exclamationmark.circle"
            static let indicatorButtonSemanticTag = "INDICATOR_BUTTON"
        }

        enum MessagesDataSource {
            static let messageTopLabelAttributedTextAttributesFontName = "SFUIText-Regular"
        }

        enum MessagesDisplayDelegate {
            static let avatarViewImageSystemName = "person.crop.circle.fill"
        }
    }
}

// swiftlint:enable identifier_name
