//
//  AppConstants+RecordingView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum RecordingView {
        public static let cancelLabelFontSize: CGFloat = 17
        public static let cancelLabelFrameHeight: CGFloat = 20
        public static let cancelLabelOffsetIncrement: CGFloat = 10

        public static let durationLabelFontSize: CGFloat = 17
        public static let durationLabelFrameHeight: CGFloat = 20

        public static let hideAnimationDuration: CGFloat = 0.2
        public static let showAnimationDuration: CGFloat = 0.3

        public static let imageViewFrameHeight: CGFloat = 30
        public static let imageViewFrameWidth: CGFloat = 30
        public static let imageViewFrameXOriginIncrement: CGFloat = 5

        public static let recordingViewLayerBorderWidth: CGFloat = 0.5
        public static let recordingViewLayerCornerRadius: CGFloat = 15

        public static let transitionAnimationDuration: CGFloat = 0.2
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum RecordingView {
        public static let cancelLabelTextColor: Color = .init(uiColor: .gray)
        public static let durationLabelTextColor: Color = .init(uiColor: .gray)
        public static let recordingViewLayerBorderColor: Color = .init(uiColor: .systemGray)
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum RecordingView {
        public static let cancelLabelFontName = "SFUIText-Semibold"
        public static let cancelLabelSemanticTag = "CANCEL_LABEL"
        public static let cancelLabelTextPrefix = "< "

        public static let durationLabelFontName = "SFUIText-Semibold"
        public static let durationLabelInitialText = "0:00"
        public static let durationLabelSemanticTag = "DURATION_LABEL"

        public static let imageViewSemanticTag = "IMAGE_VIEW"

        public static let recordingViewSemanticTag = "RECORDING_VIEW"
    }
}
