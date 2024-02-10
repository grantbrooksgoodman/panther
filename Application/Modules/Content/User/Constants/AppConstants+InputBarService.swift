//
//  AppConstants+InputBarService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 09/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum InputBarService {
        public static let layerBorderWidth: CGFloat = 0.5
        public static let layerCornerRadius: CGFloat = 15

        // swiftlint:disable:next identifier_name
        public static let recordingCancellationVibrationDelayMilliseconds: CGFloat = 50

        public static let sendButtonOnSelectedTransformScaleX: CGFloat = 1.1
        public static let sendButtonOnSelectedTransformScaleY: CGFloat = 1.1

        public static let sendButtonSizeHeight: CGFloat = 30
        public static let sendButtonSizeWidth: CGFloat = 30

        public static let transitionAnimationDuration: CGFloat = 0.3
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum InputBarService {
        public static let contentViewRecordLayerBorder: Color = .init(uiColor: .clear)
        public static let contentViewTextLayerBorder: Color = .init(uiColor: .systemGray)

        public static let inputTextViewRecordLayerBorder: Color = .init(uiColor: .systemGray)
        public static let inputTextViewTextLayerBorder: Color = .init(uiColor: .clear)

        public static let sendButtonRecordTint: Color = .init(uiColor: .red)
        public static let sendButtonTextTint: Color = .init(uiColor: .systemBlue)
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum InputBarService {
        public static let recordButtonSemanticTag = "RECORD_BUTTON"
        public static let sendButtonSemanticTag = "SEND_BUTTON"
    }
}
