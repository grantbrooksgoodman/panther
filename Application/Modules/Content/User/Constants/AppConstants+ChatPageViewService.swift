//
//  AppConstants+ChatPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ChatPageViewService {
        public static let inputBarAppearanceAnimationDuration: CGFloat = 0.2
        public static let loadMoreMessagesDelayMilliseconds: CGFloat = 200
        public static let scrollToLastItemDelayMilliseconds: CGFloat = 10

        enum AudioMessagePlayback {
            public static let playbackTimerTimeInterval: CGFloat = 0.1
            public static let playNextMessageDelayMilliseconds: CGFloat = 100
        }

        enum DeliveryProgressIndicator {
            public static let animationDelay: CGFloat = 1
            public static let animationDuration: CGFloat = 0.2

            public static let timerProgressIncrement: CGFloat = 0.001
            public static let timerProgressIncrementThreshold: CGFloat = 0.9

            public static let timerTimeInterval: CGFloat = 0.01
            public static let viewFrameHeight: CGFloat = 2
        }

        enum InputBar {
            public static let buttonOnSelectedTransformScaleX: CGFloat = 1.1
            public static let buttonOnSelectedTransformScaleY: CGFloat = 1.1

            public static let buttonSizeHeight: CGFloat = 30
            public static let buttonSizeWidth: CGFloat = 30

            public static let forceAppearanceDelayMilliseconds: CGFloat = 200

            public static let layerBorderWidth: CGFloat = 0.5
            public static let layerCornerRadius: CGFloat = 15

            public static let leftStackViewFixedSpaceWidth: CGFloat = 10
            public static let leftStackViewWidthConstant: CGFloat = 40

            // swiftlint:disable:next identifier_name
            public static let recordingCancellationVibrationDelayMilliseconds: CGFloat = 50

            // swiftlint:disable:next identifier_name
            public static let sendButtonTrailingAnchorConstraintConstantDecrement: CGFloat = 15

            public static let textContainerInsetRightIncrement: CGFloat = 10
            public static let transitionAnimationDuration: CGFloat = 0.3
        }

        enum InputBarGestureRecognizer {
            public static let errorToastPerpetuationDuration: CGFloat = 3
            public static let longPressGestureMinimumPressDuration: CGFloat = 0.3
            public static let millisecondsDelay: CGFloat = 500 // swiftlint:disable:next identifier_name
            public static let recordingInstructionToastPerpetuationDuration: CGFloat = 2.5
        }

        enum Menu { // swiftlint:disable:next identifier_name
            public static let languageRecognitionMatchConfidenceThreshold: CGFloat = 0.8
            public static let longPressGestureMinimumPressDuration: CGFloat = 0.3

            // swiftlint:disable:next identifier_name
            public static let messageContainerViewBackgroundColorDarkeningPercentage: CGFloat = 20 // swiftlint:disable:next identifier_name
            public static let messageContainerViewBackgroundColorLighteningPercentage: CGFloat = 10

            public static let selectionAnimationDuration: CGFloat = 0.2
        }

        enum RecordingUI {
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

            public static let recordingViewFrameSizeWidthDecrement: CGFloat = 10
            public static let recordingViewLayerBorderWidth: CGFloat = 0.5
            public static let recordingViewLayerCornerRadius: CGFloat = 15

            public static let transitionAnimationDuration: CGFloat = 0.2
        }

        enum TypingIndicator {
            public static let timerTimeInterval: CGFloat = 3
        }
    }
}

// MARK: - Color

public extension AppConstants.Colors {
    enum ChatPageViewService {
        enum AudioMessagePlayback {
            public static let cellCurrentUserProgressViewTint: Color = .init(uiColor: .white)
        }

        enum InputBar {
            public static let inputTextViewLayerBorder: Color = .init(uiColor: .systemGray)
            public static let inputTextViewTint: Color = .init(uiColor: .clear)

            public static let sendButtonRecordTint: Color = .init(uiColor: .red)
            public static let sendButtonTextTint: Color = .init(uiColor: .systemBlue)
        }

        enum RecordingUI {
            public static let cancelLabelTextColor: Color = .init(uiColor: .gray)
            public static let durationLabelTextColor: Color = .init(uiColor: .gray)
            public static let recordingViewLayerBorderColor: Color = .init(uiColor: .systemGray)
        }
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ChatPageViewService {
        public static let buildInfoOverlayWindowSemanticTag = "BUILD_INFO_OVERLAY_WINDOW"

        enum AudioMessagePlayback {
            public static let cellDefaultDurationLabelText = "0:00"
        }

        enum DeliveryProgressIndicator {
            public static let viewSemanticTag = "DELIVERY_PROGRESS_VIEW"
        }

        enum InputBar {
            public static let attachMediaButtonSemanticTag = "ATTACH_MEDIA_BUTTON"
            public static let recordButtonSemanticTag = "RECORD_BUTTON"
            public static let sendButtonOfflineImageSystemName = "wifi.slash"
            public static let sendButtonSemanticTag = "SEND_BUTTON"
        }

        enum InputBarGestureRecognizer { // swiftlint:disable:next line_length
            public static let audioMessagesUnsupportedAlertMessage = "Audio messages are unsupported for your language.\n\nPlease check back later in a future update!" // swiftlint:disable:next identifier_name
            public static let audioMessagesUnsupportedAlertCancelButtonTitle = "OK"
            public static let noSpeechDetectedExceptionDescriptor = "No speech detected"
        }

        enum MediaActionHandler {
            public static let defaultImageName = "image"
        }

        enum Menu {
            public static let audioMessageActionIdentifierRawValue = "audio_message"
            public static let copyActionIdentifierRawValue = "copy"
            public static let speakActionIdentifierRawValue = "speak"
            public static let viewAlterateActionIdentifierRawValue = "view_alternate"
        }

        enum RecordingUI {
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
}
