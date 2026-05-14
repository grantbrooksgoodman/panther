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

extension AppConstants.CGFloats {
    enum UserContentExtensions {
        enum AudioItem {
            static let sizeHeight: CGFloat = 40
            static let sizeWidth: CGFloat = 160
        }

        enum Date {
            static let chatPageMessageSeparatorAttributedDateStringBoldAttributesSystemFontSize: CGFloat = 12
            static let chatPageMessageSeparatorAttributedDateStringStandardAttributesSystemFontSize: CGFloat = 12

            static let chatPageMessageSeparatorAttributedDateStringUnderYearPrimaryComparator: CGFloat = -604_800
            static let chatPageMessageSeparatorAttributedDateStringUnderYearSecondaryComparator: CGFloat = -31_540_000
            static let chatPageMessageSeparatorAttributedDateStringWeekdayComparator: CGFloat = -604_800
            static let chatPageMessageSeparatorAttributedDateStringYesterdayComparator: CGFloat = -86400
        }

        enum NSAttributedString {
            static let messageCellStringParagraphLineSpacing: CGFloat = 1.25
            static let messageCellStringSystemFontSize: CGFloat = 18
        }

        enum UIView {
            static let shimmerEffectAnimationDuration: CGFloat = 1.5

            static let shimmerEffectAnimationPrimaryToValue: CGFloat = 0.8
            static let shimmerEffectAnimationSecondaryFromValue: CGFloat = 0.1
            static let shimmerEffectAnimationSecondaryToValue: CGFloat = 0.9
            static let shimmerEffectAnimationTertiaryFromValue: CGFloat = 0.2

            static let shimmerEffectGradientLayerEndPointY: CGFloat = 0.525
            static let shimmerEffectGradientLayerStartPointY: CGFloat = 0.5

            static let shimmerEffectGradientLayerFrameWidthMultiplier: CGFloat = 3

            static let shimmerEffectGradientLayerPrimaryLocation: CGFloat = 0.4
            static let shimmerEffectGradientLayerSecondaryLocation: CGFloat = 0.5
            static let shimmerEffectGradientLayerTertiaryLocation: CGFloat = 0.6
        }
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum UserContentExtensions { // NIT: Using UIColor here. || TODO: Audit this approach...
        enum Date { // swiftlint:disable line_length
            static let chatPageMessageSeparatorAttributedDateStringBoldAttributesForeground: UIColor = .init { $0.userInterfaceStyle == .dark ? .lightGray : .systemGray }
            static let chatPageMessageSeparatorAttributedDateStringStandardAttributesForeground: UIColor = .init { $0.userInterfaceStyle == .dark ? .lightGray : .systemGray } // swiftlint:enable line_length
        }

        enum Message {
            static let kindAttributedTextCurrentUserForeground: Color = .init(uiColor: .white)
            static let kindAttributedTextDarkForeground: Color = .init(uiColor: .white)
            static let kindAttributedTextLightForeground: Color = .init(uiColor: .black)
        }

        enum UIView {
            static let shimmerEffectDark: Color = .init(uiColor: .black)
            static let shimmerEffectLight: Color = .init(uiColor: .init(red: 0, green: 0, blue: 0, alpha: 0.1))
        }
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum UserContentExtensions {
        enum UIImage {
            static let averageColorCoreImageFilterName = "CIAreaAverage"
            static let documentImageSystemName = "doc.circle.fill"
            static let missingImageSystemName = "questionmark.square.dashed"
        }

        enum UIView {
            static let shimmerEffectAnimationKeyPath = "locations"
            static let shimmerEffectGradientLayerAnimationKey = "shimmer"
        }
    }
}

// swiftlint:enable identifier_name
