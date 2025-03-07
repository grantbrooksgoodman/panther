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

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ChatPageViewService {
        public static let inputBarAppearanceAnimationDuration: CGFloat = 0.2
        public static let loadMoreMessagesDelayMilliseconds: CGFloat = 200
        public static let scrollToLastItemDelayMilliseconds: CGFloat = 10 // swiftlint:disable:next identifier_name
        public static let setNavigationBarButtonItemAppearanceDelayMilliseconds: CGFloat = 10

        enum AudioMessagePlayback {
            public static let playbackTimerTimeInterval: CGFloat = 0.1
            public static let playNextMessageDelayMilliseconds: CGFloat = 100
        }

        enum ContextMenu {
            // swiftlint:disable identifier_name
            public static let doubleTapGestureNumberOfTapsRequired: CGFloat = 2

            public static let interactionTimerTimeInterval: CGFloat = 0.1
            public static let interactionScrollToLastItemDelayMilliseconds: CGFloat = 60

            public static let isLastMessageVisibleScrollViewOffsetLowerBoundDecrement: CGFloat = 150
            public static let isLastMessageVisibleScrollViewOffsetUpperBoundIncrement: CGFloat = 150

            public static let languageRecognitionMatchConfidenceThreshold: CGFloat = 0.8
            public static let longPressGestureMinimumPressDuration: CGFloat = 0.5

            public static let menuStyleBottomMargin: CGFloat = 8
            public static let menuStyleTopMargin: CGFloat = 8

            public static let menuStyleTransformScaleX: CGFloat = 1.08
            public static let menuStyleTransformScaleY: CGFloat = 1.08

            public static let reactionScrollToLastItemDelayMilliseconds: CGFloat = 200
            public static let triggerExistingSelectionDelayMilliseconds: CGFloat = 10
            // swiftlint:enable identifier_name
        }

        enum DeliveryProgressIndicator {
            public static let animationDelay: CGFloat = 1
            public static let animationDuration: CGFloat = 0.2

            public static let appearanceTimerTimeInterval: CGFloat = 5
            public static let hiddenTimerTimeInterval: CGFloat = 0.05
            public static let visibleTimerTimeInterval: CGFloat = 0.01

            public static let timerProgressIncrement: CGFloat = 0.001
            public static let timerProgressIncrementThreshold: CGFloat = 0.9

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

        enum MediaActionHandler {
            public static let avAssetImageGeneratorPreferredTimescale: CGFloat = 600
            public static let imageCompressionSizeKB: CGFloat = 1000
            public static let thumbnailImageScale: CGFloat = 2
            public static let thumbnailImageSizeHeight: CGFloat = 500
            public static let thumbnailImageSizeWidth: CGFloat = 500
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
    enum ChatPageViewService { // swiftlint:disable:next identifier_name
        public static let messagesCollectionViewPrimaryDarkBackground: Color = .black // swiftlint:disable:next identifier_name
        public static let messagesCollectionViewSecondaryDarkBackground: Color = .init(uiColor: .init(hex: 0x1C1C1E))

        enum AudioMessagePlayback {
            public static let cellCurrentUserProgressViewTint: Color = .init(uiColor: .white)
        }

        enum DeliveryProgressIndicator {
            public static let prevaricationModeProgressTint: Color = .init(uiColor: .init(hex: 0x4B6584))
        }

        enum InputBar {
            public static let inputTextViewLayerBorder: Color = .init(uiColor: .systemGray)
            public static let inputTextViewTint: Color = .init(uiColor: .clear)

            public static let prevaricationModeBackground: Color = .init(uiColor: .init(hex: 0xF8F8F8))

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
        public static let barButtonItemViewID = "_UIModernBarButton"
        public static let chatPageViewPreviewViewControllerID = "UIHostingController<ModifiedContent<ChatPageView, _BackgroundStyleModifier<Color>>>"
        public static let editingOverlayViewControllerID = "UIEditingOverlayViewController"
        public static let frontmostViewControllerID = "ChatPageViewController"
        public static let inputWindowControllerID = "UIInputWindowController"
        public static let navigationStackHostingControllerID = "NavigationStackHostingController<AnyView>"

        enum AudioMessagePlayback {
            public static let cellDefaultDurationLabelText = "0:00"
        }

        enum ContextMenu { // swiftlint:disable:next identifier_name
            public static let audioMessageActionAlternateImageSystemName = "text.bubble"
            public static let audioMessageActionIdentifierRawValue = "audio_message"
            public static let audioMessageActionImageSystemName = "speaker.wave.2.bubble"

            public static let copyActionIdentifierRawValue = "copy"
            public static let copyActionImageSystemName = "doc.on.doc"

            public static let speakActionAlternateImageSystemName = "speaker.slash.circle"
            public static let speakActionIdentifierRawValue = "speak"
            public static let speakActionImageSystemName = "speaker.wave.2.circle"

            public static let viewAlterateActionIdentifierRawValue = "view_alternate"
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
            public static let defaultDocumentName = "document"
            public static let defaultImageName = "image"
            public static let defaultVideoName = "video"
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
