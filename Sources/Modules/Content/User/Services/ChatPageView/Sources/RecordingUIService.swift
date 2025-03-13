//
//  RecordingUIService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView

public final class RecordingUIService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.RecordingUI
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecordingUI
    private typealias Strings = AppConstants.Strings.ChatPageViewService.RecordingUI

    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.commonServices.audio.recording) private var recordingService: RecordingService

    // MARK: - Properties

    public var isShowingRecordingUI = false

    private let viewController: ChatPageViewController

    private var durationLabelTimer: Timer?
    private var recordingDuration = 0

    // MARK: - Computed Properties

    // UILabel
    private var cancelLabel: UILabel? { recordingView?.firstSubview(for: Strings.cancelLabelSemanticTag) as? UILabel }
    private var durationLabel: UILabel? { recordingView?.firstSubview(for: Strings.durationLabelSemanticTag) as? UILabel }

    // Other
    private var imageView: UIImageView? { recordingView?.firstSubview(for: Strings.imageViewSemanticTag) as? UIImageView }
    private var inputBar: InputBarAccessoryView { viewController.messageInputBar }
    private var recordingView: UIView? { inputBar.contentView.firstSubview(for: Strings.recordingViewSemanticTag) }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Object Lifecycle

    deinit {
        resetSession()
    }

    // MARK: - Toggle Recording UI

    public func hideRecordingUI() async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                UIView.animate(withDuration: Floats.hideAnimationDuration) {
                    typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar
                    self.recordingView?.alpha = 0

                    self.inputBar.inputTextView.layer.borderWidth = Floats.layerBorderWidth
                    self.inputBar.inputTextView.placeholder = " \(Localized(.newMessage).wrappedValue)"
                    self.inputBar.inputTextView.textInputView.isUserInteractionEnabled = true
                    self.inputBar.inputTextView.tintColor = .accent
                    self.inputBar.leftStackView.attachMediaButton?.alpha = 1
                } completion: { _ in
                    self.inputBar.contentView.removeSubviews(for: Strings.recordingViewSemanticTag, animated: false)
                    self.resetSession()
                    self.isShowingRecordingUI = false
                    continuation.resume()
                }
            }
        }
    }

    public func showRecordingUI() async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                isShowingRecordingUI = true

                let viewComponents = buildRecordingView()

                let recordingView = viewComponents.view
                let cancelLabel = viewComponents.cancelLabel
                let durationLabel = viewComponents.durationLabel
                let imageView = viewComponents.imageView

                inputBar.contentView.addSubview(recordingView)
                recordingView.center = inputBar.inputTextView.center
                recordingView.tag = coreUI.semTag(for: Strings.recordingViewSemanticTag)

                cancelLabel.center.y = recordingView.center.y
                durationLabel.center.y = recordingView.center.y
                imageView.center.y = recordingView.center.y
                durationLabel.center.y = imageView.center.y

                UIView.animate(withDuration: Floats.showAnimationDuration) {
                    typealias Colors = AppConstants.Colors.ChatPageViewService.InputBar

                    self.inputBar.inputTextView.layer.borderWidth = 0
                    self.inputBar.inputTextView.placeholder = nil
                    self.inputBar.inputTextView.textInputView.isUserInteractionEnabled = false
                    self.inputBar.inputTextView.tintColor = UIColor(Colors.inputTextViewTint)
                    self.inputBar.leftStackView.attachMediaButton?.alpha = 0

                    recordingView.alpha = 1
                }

                let offset = cancelLabel.intrinsicContentSize.width + Floats.cancelLabelOffsetIncrement
                let maxXToOffset = recordingView.frame.maxX - offset

                UIView.animate(
                    withDuration: Floats.showAnimationDuration,
                    delay: 0,
                    options: [.curveEaseIn]
                ) {
                    let distanceFromMax = cancelLabel.frame.origin.x - maxXToOffset
                    for _ in 0 ... Int(distanceFromMax) {
                        guard cancelLabel.frame.origin.x != maxXToOffset else { return }
                        cancelLabel.frame.origin.x -= 1
                    }
                } completion: { _ in
                    cancelLabel.frame.origin.x = maxXToOffset
                    cancelLabel.addShimmerEffect()

                    if self.durationLabelTimer != nil {
                        self.resetSession()
                    }

                    self.durationLabelTimer = Timer.scheduledTimer(
                        timeInterval: 1,
                        target: self,
                        selector: #selector(self.animateRecording),
                        userInfo: nil,
                        repeats: true
                    )

                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Auxiliary

    @objc
    private func animateRecording() {
        guard let durationLabelTimer,
              durationLabelTimer.isValid,
              recordingService.isInOrWillTransitionToRecordingState,
              inputBar.sendButton.isRecordButton,
              let durationLabel,
              let imageView else {
            resetSession()
            dismantleRecordingSession()
            return
        }

        recordingDuration += 1

        durationLabel.text = Float(recordingDuration).durationString
        durationLabel.frame.size.width = durationLabel.intrinsicContentSize.width

        let recordingImage = UIImage(resource: .recording)
        let recordingImageFilled = UIImage(resource: .recordingFilled)

        UIView.transition(
            with: imageView,
            duration: Floats.transitionAnimationDuration,
            options: .transitionCrossDissolve
        ) {
            let isImageFilled = imageView.image == recordingImageFilled
            imageView.image = isImageFilled ? recordingImage : recordingImageFilled
        }
    }

    /// - NOTE: Fixes a bug in which typing immediately after beginning recording would fail to cancel recording.
    private func dismantleRecordingSession() {
        Logger.log(
            "Intercepted typing while recording bug.",
            domain: .bugPrevention,
            metadata: [self, #file, #function, #line]
        )

        Task { @MainActor in
            await hideRecordingUI()
        }

        if let exception = recordingService.cancelRecording() {
            guard !exception.isEqual(to: .noAudioRecorderToStop) else { return }
            Logger.log(exception, with: .toast())
        }
    }

    private func resetSession() {
        durationLabelTimer?.invalidate()
        durationLabelTimer = nil
        recordingDuration = 0
    }

    // MARK: - View Builders

    private func buildCancelLabel() -> UILabel {
        let cancelLabel = UILabel()
        cancelLabel.text = "\(Strings.cancelLabelTextPrefix)\(Localized(.slideToCancel).wrappedValue)"

        cancelLabel.baselineAdjustment = .alignCenters
        cancelLabel.font = UIFont(name: Strings.cancelLabelFontName, size: Floats.cancelLabelFontSize)
        cancelLabel.textAlignment = .center
        cancelLabel.textColor = UIColor(Colors.cancelLabelTextColor)

        cancelLabel.frame.size.width = cancelLabel.intrinsicContentSize.width
        cancelLabel.frame.size.height = Floats.cancelLabelFrameHeight

        return cancelLabel
    }

    private func buildDurationLabel() -> UILabel {
        let durationLabel = UILabel()
        durationLabel.text = Strings.durationLabelInitialText

        durationLabel.baselineAdjustment = .alignCenters
        durationLabel.font = UIFont(name: Strings.durationLabelFontName, size: Floats.durationLabelFontSize)
        durationLabel.textAlignment = .center
        durationLabel.textColor = UIColor(Colors.durationLabelTextColor)

        durationLabel.frame.size.width = durationLabel.intrinsicContentSize.width
        durationLabel.frame.size.height = Floats.durationLabelFrameHeight

        return durationLabel
    }

    private func buildImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.frame = CGRect(
            origin: .zero,
            size: .init(
                width: Floats.imageViewFrameWidth,
                height: Floats.imageViewFrameHeight
            )
        )

        imageView.image = UIImage(resource: .recording)
        return imageView
    }

    // swiftlint:disable:next large_tuple
    private func buildRecordingView() -> (
        view: UIView,
        cancelLabel: UILabel,
        durationLabel: UILabel,
        imageView: UIImageView
    ) {
        let recordingView = UIView()
        recordingView.backgroundColor = inputBar.inputTextView.backgroundColor
        recordingView.frame = inputBar.inputTextView.frame
        recordingView.frame.size.width -= Floats.recordingViewFrameSizeWidthDecrement

        recordingView.clipsToBounds = true
        recordingView.layer.borderColor = UIColor(Colors.recordingViewLayerBorderColor).cgColor
        recordingView.layer.borderWidth = Floats.recordingViewLayerBorderWidth
        recordingView.layer.cornerRadius = Floats.recordingViewLayerCornerRadius

        let cancelLabel = buildCancelLabel()
        recordingView.addSubview(cancelLabel)
        cancelLabel.frame.origin.x = recordingView.frame.maxX
        cancelLabel.tag = coreUI.semTag(for: Strings.cancelLabelSemanticTag)

        let durationLabel = buildDurationLabel()
        recordingView.addSubview(durationLabel)
        durationLabel.frame.origin.x = recordingView.frame.origin.x + durationLabel.intrinsicContentSize.width
        durationLabel.tag = coreUI.semTag(for: Strings.durationLabelSemanticTag)

        let imageView = buildImageView()
        recordingView.addSubview(imageView)
        imageView.frame.origin.x = recordingView.frame.origin.x + Floats.imageViewFrameXOriginIncrement
        imageView.tag = coreUI.semTag(for: Strings.imageViewSemanticTag)

        guard let cancelLabel = recordingView.firstSubview(for: Strings.cancelLabelSemanticTag) as? UILabel,
              let durationLabel = recordingView.firstSubview(for: Strings.durationLabelSemanticTag) as? UILabel,
              let imageView = recordingView.firstSubview(for: Strings.imageViewSemanticTag) as? UIImageView else {
            return (
                recordingView,
                cancelLabel,
                durationLabel,
                imageView
            )
        }

        return (
            recordingView,
            cancelLabel,
            durationLabel,
            imageView
        )
    }
}
