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

extension AppConstants.CGFloats {
    enum ChatPageViewService {
        static let inputBarAppearanceAnimationDuration: CGFloat = 0.2
        static let loadMoreMessagesDelayMilliseconds: CGFloat = 200
        static let scrollDelayMilliseconds: CGFloat = 10 // swiftlint:disable:next identifier_name
        static let setNavigationBarButtonItemAppearanceDelayMilliseconds: CGFloat = 10 // swiftlint:disable:next identifier_name
        static let triggerFocusedMessageCellInteractionDelayMilliseconds: CGFloat = 500

        enum AudioMessagePlayback {
            static let playbackTimerTimeInterval: CGFloat = 0.1
            static let playNextMessageDelayMilliseconds: CGFloat = 100
        }

        enum ContextMenu {
            // swiftlint:disable identifier_name
            static let doubleTapGestureNumberOfTapsRequired: CGFloat = 2

            static let interactionTimerTimeInterval: CGFloat = 0.1
            static let interactionScrollToLastItemDelayMilliseconds: CGFloat = 60

            static let isLastMessageVisibleScrollViewOffsetLowerBoundDecrement: CGFloat = 150
            static let isLastMessageVisibleScrollViewOffsetUpperBoundIncrement: CGFloat = 150

            static let languageRecognitionMatchConfidenceThreshold: CGFloat = 0.8
            static let longPressGestureMinimumPressDuration: CGFloat = 0.5

            static let menuStyleBottomMargin: CGFloat = 8
            static let menuStyleTopMargin: CGFloat = 8

            static let menuStyleTransformScaleX: CGFloat = 1.08
            static let menuStyleTransformScaleY: CGFloat = 1.08

            static let reactionScrollToLastItemDelayMilliseconds: CGFloat = 200
            static let triggerExistingSelectionDelayMilliseconds: CGFloat = 10
            // swiftlint:enable identifier_name
        }

        enum DeliveryProgressIndicator {
            static let animationDelay: CGFloat = 1
            static let animationDuration: CGFloat = 0.2

            static let appearanceTimerTimeInterval: CGFloat = 5
            static let hiddenTimerTimeInterval: CGFloat = 0.05
            static let visibleTimerTimeInterval: CGFloat = 0.01

            static let timerProgressIncrement: CGFloat = 0.001
            static let timerProgressIncrementThreshold: CGFloat = 0.9

            static let viewFrameHeight: CGFloat = 2
        }

        enum InputBar {
            static let buttonOnSelectedTransformScaleX: CGFloat = 1.1
            static let buttonOnSelectedTransformScaleY: CGFloat = 1.1

            static let buttonSizeHeight: CGFloat = 30
            static let buttonSizeWidth: CGFloat = 30

            static let consentButtonFontSize: CGFloat = 17
            static let consentButtonFrameWidthDecrement: CGFloat = 20 // swiftlint:disable:next identifier_name
            static let consentButtonTitleLabelMinimumScaleFactor: CGFloat = 0.5

            static let forceAppearanceDelayMilliseconds: CGFloat = 200

            static let layerBorderWidth: CGFloat = 0.5
            static let layerCornerRadius: CGFloat = 15

            static let leftStackViewFixedSpaceWidth: CGFloat = 10
            static let leftStackViewWidthConstant: CGFloat = 40

            // swiftlint:disable:next identifier_name
            static let recordingCancellationVibrationDelayMilliseconds: CGFloat = 50

            // swiftlint:disable:next identifier_name
            static let sendButtonTrailingAnchorConstraintConstantDecrement: CGFloat = 15

            static let textContainerInsetRightIncrement: CGFloat = 10
            static let transitionAnimationDuration: CGFloat = 0.3

            static let v26AttachMediaButtonSize: CGFloat = 34
            static let v26TextContainerHorizontalInset: CGFloat = 6
            static let v26TextContainerVerticalInset: CGFloat = 10
        }

        enum InputBarGestureRecognizer {
            static let errorToastPerpetuationDuration: CGFloat = 3
            static let longPressGestureMinimumPressDuration: CGFloat = 0.3
            static let millisecondsDelay: CGFloat = 500 // swiftlint:disable:next identifier_name
            static let recordingInstructionToastPerpetuationDuration: CGFloat = 2.5
        }

        enum MediaActionHandler {
            static let avAssetImageGeneratorPreferredTimescale: CGFloat = 600
            static let imageCompressionSizeKB: CGFloat = 1000
            static let thumbnailImageScale: CGFloat = 2
            static let thumbnailImageSizeHeight: CGFloat = 500
            static let thumbnailImageSizeWidth: CGFloat = 500
        }

        enum RecordingUI {
            static let cancelLabelFontSize: CGFloat = 17
            static let cancelLabelFrameHeight: CGFloat = 20
            static let cancelLabelOffsetIncrement: CGFloat = 10

            static let durationLabelFontSize: CGFloat = 17
            static let durationLabelFrameHeight: CGFloat = 20

            static let hideAnimationDuration: CGFloat = 0.2
            static let showAnimationDuration: CGFloat = 0.3

            static let imageViewFrameHeight: CGFloat = 30
            static let imageViewFrameWidth: CGFloat = 30
            static let imageViewFrameXOriginIncrement: CGFloat = 5

            static let recordingViewFrameSizeWidthDecrement: CGFloat = 10
            static let recordingViewLayerBorderWidth: CGFloat = 0.5
            static let recordingViewLayerCornerRadius: CGFloat = 15

            static let transitionAnimationDuration: CGFloat = 0.2
        }

        enum TypingIndicator {
            static let timerTimeInterval: CGFloat = 3
        }
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum ChatPageViewService { // swiftlint:disable:next identifier_name
        static let messagesCollectionViewPrimaryDarkBackground: Color = .black // swiftlint:disable:next identifier_name
        static let messagesCollectionViewSecondaryDarkBackground: Color = .init(uiColor: .init(hex: 0x1C1C1E))

        enum AudioMessagePlayback {
            static let cellCurrentUserProgressViewTint: Color = .init(uiColor: .white)
        }

        enum DeliveryProgressIndicator {
            static let prevaricationModeProgressTint: Color = .init(uiColor: .init(hex: 0x4B6584))
            static let progressBarTint: Color = .init(uiColor: .systemBlue)
        }

        enum InputBar {
            /* MARK: Properties */

            static let inputTextViewAlternateTint: Color = .init(uiColor: .clear)
            static let inputTextViewLayerBorder: Color = .init(uiColor: .systemGray)

            static let prevaricationModeBackground: Color = .init(uiColor: .init(hex: 0xF8F8F8))

            static let sendButtonRecordTint: Color = .init(uiColor: .red)
            static let sendButtonTextTint: Color = .init(uiColor: .systemBlue)

            /* MARK: Computed Properties */

            @MainActor
            static var inputTextViewTint: Color {
                .init(uiColor: .accentOrSystemBlue)
            }
        }

        enum RecordingUI {
            static let cancelLabelTextColor: Color = .init(uiColor: .gray)
            static let durationLabelTextColor: Color = .init(uiColor: .gray)
            static let recordingViewLayerBorderColor: Color = .init(uiColor: .systemGray)
        }
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatPageViewService {
        static let barButtonItemViewID = "_UIModernBarButton" // swiftlint:disable:next line_length
        static let chatPageViewPreviewHostingControllerID = "UIHostingController<IDView<ModifiedContent<ChatPageView, _BackgroundStyleModifier<Color>>, ConversationID>>"
        static let leafViewControllerID = "ChatPageViewController"

        enum AudioMessagePlayback {
            static let cellDefaultDurationLabelText = "0:00"
        }

        enum ContextMenu { // swiftlint:disable identifier_name
            static let audioMessageActionAlternateImageSystemName = "text.bubble"
            static let audioMessageActionIdentifierRawValue = "audio_message"
            static let audioMessageActionImageSystemName = "speaker.wave.2.bubble"

            static let copyActionIdentifierRawValue = "copy"
            static let copyActionImageSystemName = "doc.on.doc"

            static let reactionDetailsActionIdentifierRawValue = "reaction_details"
            static let reactionDetailsActionImageSystemName = "info.circle"

            static let reportMistranslationActionIdentifierRawValue = "report_mistranslation"
            static let reportMistranslationActionImageSystemName = "flag"

            static let retryTranslationActionIdentifierRawValue = "retry_translation"
            static let retryTranslationActionImageSystemName = "arrow.counterclockwise"

            static let saveActionIdentifierRawValue = "save"
            static let saveActionImageSystemName = "square.and.arrow.down"

            static let speakActionAlternateImageSystemName = "speaker.slash.circle"
            static let speakActionIdentifierRawValue = "speak"
            static let speakActionImageSystemName = "speaker.wave.2.circle"

            static let viewAlterateActionIdentifierRawValue = "view_alternate"
            // swiftlint:enable identifier_name
        }

        enum DeliveryProgressIndicator {
            static let viewSemanticTag = "DELIVERY_PROGRESS_VIEW"
        }

        enum InputBar {
            static let attachMediaButtonSemanticTag = "ATTACH_MEDIA_BUTTON"

            static let consentButtonSemanticTag = "CONSENT_BUTTON"

            static let recordButtonSemanticTag = "RECORD_BUTTON"

            static let sendButtonOfflineImageSystemName = "wifi.slash"
            static let sendButtonSemanticTag = "SEND_BUTTON" // swiftlint:disable:next identifier_name
            static let sendButtonStorageLimitReachedImageSystemName = "externaldrive.trianglebadge.exclamationmark"

            static let v26AttachMediaButtonImageSystemName = "plus"
        }

        enum InputBarGestureRecognizer { // swiftlint:disable:next line_length
            static let audioMessagesUnsupportedAlertMessage = "Audio messages are unsupported for your language.\n\nPlease check back later in a future update!" // swiftlint:disable:next identifier_name
            static let audioMessagesUnsupportedAlertCancelButtonTitle = "OK"
            static let noSpeechDetectedExceptionDescriptor = "No speech detected"
        }

        enum MediaActionHandler {
            static let defaultDocumentName = "document"
            static let defaultImageName = "image"
            static let defaultVideoName = "video"
        }

        enum RecordingUI {
            static let cancelLabelFontName = "SFUIText-Semibold"
            static let cancelLabelSemanticTag = "CANCEL_LABEL"
            static let cancelLabelTextPrefix = "< "

            static let durationLabelFontName = "SFUIText-Semibold"
            static let durationLabelInitialText = "0:00"
            static let durationLabelSemanticTag = "DURATION_LABEL"

            static let imageViewSemanticTag = "IMAGE_VIEW"

            static let recordingViewSemanticTag = "RECORDING_VIEW"
        }
    }
}
