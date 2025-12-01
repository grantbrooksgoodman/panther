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
        static let messagesCollectionViewPrevaricationModeBackground: Color = .init(uiColor: .init(hex: 0xF3EDE6))

        enum AVSpeechSynthesizerDelegate {
            static let willSpeakRangeOfSpeechStringHighlight: Color = .init(uiColor: .red)
            static let willSpeakRangeOfSpeechStringNotWhite: Color = .init(uiColor: .black)
            static let willSpeakRangeOfSpeechStringWhite: Color = .init(uiColor: .white)
        }

        enum MessagesDataSource {
            static let cellBottomLabelAttributedTextBoldAttributesForeground: Color = .init(uiColor: .gray)
            static let cellBottomLabelAttributedTextStandardAttributesForeground: Color = .init(uiColor: .lightGray)

            static let currentUserAudioTintColor: Color = .init(uiColor: .white)

            static let messageTimestampLabelAttributedTextAttributesForeground: Color = .init(uiColor: .lightGray)
            static let messageTopLabelAttributedTextAttributesForeground: Color = .init(uiColor: .systemGray)
        }

        enum MessagesDisplayDelegate {
            static let audioCellProgressViewCurrentUserAccent: Color = .init(uiColor: .white)

            static let detectorAttributesAlternateForeground: Color = .init(uiColor: .black)
            static let detectorAttributesPrimaryForeground: Color = .init(uiColor: .white)

            static let genericAvatarViewBackground: Color = .init(uiColor: .clear)
            static let genericAvatarViewTint: Color = .init(uiColor: .gray)

            static let messageStyleCustomLayerShadowColor: Color = .init(uiColor: .black)

            static let penPalsAvatarViewBackground: Color = .init(uiColor: .clear)
            static let penPalsAvatarViewTint: Color = .init(uiColor: .purple)
        }
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatPageView {
        enum MessagesDataSource {
            static let messageTopLabelAttributedTextAttributesFontName = "SFUIText-Regular"
        }

        enum MessagesDisplayDelegate {
            static let avatarViewImageSystemName = "person.crop.circle.fill"
        }
    }
}

// swiftlint:enable identifier_name
