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

/* Proprietary */
import AppSubsystem

// swiftlint:disable identifier_name

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ChatPageView {
        public static let messageLabelInset: CGFloat = 4

        public static let messageOutgoingCellBottomLabelAlignmentRightTextInset: CGFloat = 10
        public static let messageOutgoingCellBottomLabelAlignmentTopTextInset: CGFloat = 2

        public static let textCellMessageLabelLeftTextInset: CGFloat = 15
        public static let textCellMessageLabelRightTextInset: CGFloat = 1

        enum AVSpeechSynthesizerDelegate {
            public static let attributedStringParagraphStyleLineSpacing: CGFloat = 1.25
        }

        enum MessagesDataSource {
            public static let cellBottomLabelAttributedTextBoldAttributesSystemFontSize: CGFloat = 12
            public static let cellBottomLabelAttributedTextEmojiAttributesSystemFontSize: CGFloat = 14
            public static let cellBottomLabelAttributedTextStandardAttributesSystemFontSize: CGFloat = 12

            public static let messageTimestampLabelAttributedTextAttributesSystemFontSize: CGFloat = 12
            public static let messageTopLabelAttributedTextAttributesBaselineOffset: CGFloat = 3
            public static let messageTopLabelAttributedTextAttributesFontSize: CGFloat = 10.5
        }

        enum MessagesDisplayDelegate {
            public static let audioCellProgressViewTrackTintColorAlphaComponent: CGFloat = 0.8
            public static let audioCellProgressViewTrackTintColorDarkeningPercentage: CGFloat = 6

            public static let messageStyleCustomLayerCornerRadius: CGFloat = 10
            public static let messageStyleCustomLayerShadowOffsetHeight: CGFloat = 2
            public static let messageStyleCustomLayerShadowOpacity: CGFloat = 0.1
            public static let messageStyleCustomLayerShadowRadius: CGFloat = 4
        }

        enum MessagesLayoutDelegate {
            public static let cellBottomLabelHeight: CGFloat = 20
            public static let cellTopLabelHeight: CGFloat = 25
            public static let cellTopLabelHeightSentDateSecondsComparator: CGFloat = 5400
            public static let messageTopLabelHeight: CGFloat = 15
        }

        enum UITextViewDelegate {
            public static let setButtonsIsEnabledDelayMilliseconds: CGFloat = 100
            public static let toggleLabelRepresentationDelayMilliseconds: CGFloat = 10
        }
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ChatPageView {
        public static let messagesCollectionViewPrevaricationModeBackground: Color = .init(uiColor: .init(hex: 0xF3EDE6))

        enum AVSpeechSynthesizerDelegate {
            public static let willSpeakRangeOfSpeechStringHighlight: Color = .init(uiColor: .red)
            public static let willSpeakRangeOfSpeechStringNotWhite: Color = .init(uiColor: .black)
            public static let willSpeakRangeOfSpeechStringWhite: Color = .init(uiColor: .white)
        }

        enum MessagesDataSource {
            public static let cellBottomLabelAttributedTextBoldAttributesForeground: Color = .init(uiColor: .gray)
            public static let cellBottomLabelAttributedTextStandardAttributesForeground: Color = .init(uiColor: .lightGray)

            public static let currentUserAudioTintColor: Color = .init(uiColor: .white)

            public static let messageTimestampLabelAttributedTextAttributesForeground: Color = .init(uiColor: .lightGray)
            public static let messageTopLabelAttributedTextAttributesForeground: Color = .init(uiColor: .systemGray)
        }

        enum MessagesDisplayDelegate {
            public static let audioCellProgressViewCurrentUserAccent: Color = .init(uiColor: .white)

            public static let detectorAttributesAlternateForeground: Color = .init(uiColor: .black)
            public static let detectorAttributesPrimaryForeground: Color = .init(uiColor: .white)

            public static let genericAvatarViewBackground: Color = .init(uiColor: .clear)
            public static let genericAvatarViewTint: Color = .init(uiColor: .gray)

            public static let messageStyleCustomLayerShadowColor: Color = .init(uiColor: .black)

            public static let penPalsAvatarViewBackground: Color = .init(uiColor: .clear)
            public static let penPalsAvatarViewTint: Color = .init(uiColor: .purple)
        }
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ChatPageView {
        enum MessagesDataSource {
            public static let messageTopLabelAttributedTextAttributesFontName = "SFUIText-Regular"
        }

        enum MessagesDisplayDelegate {
            public static let avatarViewImageSystemName = "person.crop.circle.fill"
        }
    }
}

// swiftlint:enable identifier_name
