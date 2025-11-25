//
//  AppConstants+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
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
    enum UserContentExtensions {
        enum AudioItem {
            public static let sizeHeight: CGFloat = 40
            public static let sizeWidth: CGFloat = 160
        }

        enum Date {
            public static let chatPageMessageSeparatorAttributedDateStringBoldAttributesSystemFontSize: CGFloat = 12
            public static let chatPageMessageSeparatorAttributedDateStringStandardAttributesSystemFontSize: CGFloat = 12

            public static let chatPageMessageSeparatorAttributedDateStringUnderYearPrimaryComparator: CGFloat = -604_800
            public static let chatPageMessageSeparatorAttributedDateStringUnderYearSecondaryComparator: CGFloat = -31_540_000
            public static let chatPageMessageSeparatorAttributedDateStringWeekdayComparator: CGFloat = -604_800
            public static let chatPageMessageSeparatorAttributedDateStringYesterdayComparator: CGFloat = -86400
        }

        enum NSAttributedString {
            public static let messageCellStringParagraphLineSpacing: CGFloat = 1.25
            public static let messageCellStringSystemFontSize: CGFloat = 18
        }

        enum UIView {
            public static let shimmerEffectAnimationDuration: CGFloat = 1.5

            public static let shimmerEffectAnimationPrimaryToValue: CGFloat = 0.8
            public static let shimmerEffectAnimationSecondaryFromValue: CGFloat = 0.1
            public static let shimmerEffectAnimationSecondaryToValue: CGFloat = 0.9
            public static let shimmerEffectAnimationTertiaryFromValue: CGFloat = 0.2

            public static let shimmerEffectGradientLayerEndPointY: CGFloat = 0.525
            public static let shimmerEffectGradientLayerStartPointY: CGFloat = 0.5

            public static let shimmerEffectGradientLayerFrameWidthMultiplier: CGFloat = 3

            public static let shimmerEffectGradientLayerPrimaryLocation: CGFloat = 0.4
            public static let shimmerEffectGradientLayerSecondaryLocation: CGFloat = 0.5
            public static let shimmerEffectGradientLayerTertiaryLocation: CGFloat = 0.6
        }
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum UserContentExtensions { // NIT: Using UIColor here.
        enum Date { // swiftlint:disable line_length
            public static let chatPageMessageSeparatorAttributedDateStringBoldAttributesForeground: UIColor = ThemeService.isDarkModeActive ? .lightGray : .gray
            public static let chatPageMessageSeparatorAttributedDateStringStandardAttributesForeground: UIColor = ThemeService.isDarkModeActive ? .lightGray : .gray // swiftlint:enable line_length
        }

        enum Message {
            public static let kindAttributedTextCurrentUserForeground: Color = .init(uiColor: .white)
            public static let kindAttributedTextDarkForeground: Color = .init(uiColor: .white)
            public static let kindAttributedTextLightForeground: Color = .init(uiColor: .black)
        }

        enum UIView {
            public static let shimmerEffectDark: Color = .init(uiColor: .black)
            public static let shimmerEffectLight: Color = .init(uiColor: .init(red: 0, green: 0, blue: 0, alpha: 0.1))
        }
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum UserContentExtensions {
        enum UIImage {
            public static let averageColorCoreImageFilterName = "CIAreaAverage"
            public static let documentImageSystemName = "doc.circle.fill"
            public static let missingImageSystemName = "questionmark.square.dashed"
        }

        enum UIView {
            public static let shimmerEffectAnimationKeyPath = "locations"
            public static let shimmerEffectGradientLayerAnimationKey = "shimmer"
        }
    }
}

// swiftlint:enable identifier_name
