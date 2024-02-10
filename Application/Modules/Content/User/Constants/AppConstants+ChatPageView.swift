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
        /* MARK: ChatPageView */

        public static let messageOutgoingCellBottomLabelAlignmentRightTextInset: CGFloat = 10
        public static let messageOutgoingCellBottomLabelAlignmentTopTextInset: CGFloat = 2

        public static let textCellMessageLabelLeftTextInset: CGFloat = 15
        public static let textCellMessageLabelRightTextInset: CGFloat = 1

        /* MARK: MessagesDataSource */

        enum MessagesDataSource {
            public static let cellBottomLabelAttributedTextBoldAttributesSystemFontSize: CGFloat = 12
            public static let cellBottomLabelAttributedTextStandardAttributesSystemFontSize: CGFloat = 12

            public static let messageTopLabelAttributedTextAttributesFontSize: CGFloat = 10.5
        }

        /* MARK: MessagesDisplayDelegate */

        enum MessagesDisplayDelegate {
            public static let audioCellProgressViewDefaultThemeTrackTintColorAlphaComponent: CGFloat = 0.8
            public static let audioCellProgressViewDefaultThemeTrackTintColorDarkeningPercentage: CGFloat = 6

            public static let messageStyleCustomLayerCornerRadius: CGFloat = 10
        }

        /* MARK: MessagesLayoutDelegate */

        enum MessagesLayoutDelegate {
            public static let cellBottomLabelHeight: CGFloat = 20
            public static let cellTopLabelHeight: CGFloat = 25
            public static let cellTopLabelHeightSentDateSecondsComparator: CGFloat = 5400
            public static let messageTopLabelHeight: CGFloat = 15
        }
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ChatPageView {
        /* MARK: MessagesDataSource */

        enum MessagesDataSource {
            public static let cellBottomLabelAttributedTextBoldAttributesForeground: Color = .init(uiColor: .gray)
            public static let cellBottomLabelAttributedTextStandardAttributesForeground: Color = .init(uiColor: .lightGray)

            public static let currentUserAudioTintColor: Color = .init(uiColor: .white)
            public static let messageTopLabelAttributedTextAttributesForeground: Color = .init(uiColor: .systemGray)
        }

        /* MARK: MessagesDisplayDelegate */

        enum MessagesDisplayDelegate {
            public static let detectorAttributesAlternateForeground: Color = .init(uiColor: .black)
            public static let detectorAttributesPrimaryForeground: Color = .init(uiColor: .white)

            public static let genericAvatarViewBackground: Color = .init(uiColor: .clear)
            public static let genericAvatarViewTint: Color = .init(uiColor: .gray)
        }
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ChatPageView {
        /* MARK: MessagesDataSource */

        enum MessagesDataSource {
            public static let messageTopLabelAttributedTextAttributesFontName = "SFUIText-Regular"
        }

        /* MARK: MessageCellDelegate */

        enum MessageCellDelegate {
            public static let dateSelectionURLString = "calshow:"
            public static let phoneNumberSelectionURLString = "tel://"
        }
    }
}

// swiftlint:enable identifier_name
