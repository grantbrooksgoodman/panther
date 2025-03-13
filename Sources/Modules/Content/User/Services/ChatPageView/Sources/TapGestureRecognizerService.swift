//
//  TapGestureRecognizerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/11/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

public final class TapGestureRecognizerService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.attributeDetection) private var attributeDetectionService: AttributeDetectionService
    @Dependency(\.chatPageViewService.mediaMessagePreview) private var mediaMessagePreviewService: MediaMessagePreviewService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Configure Gesture Recognizer

    public func configureGestureRecognizer() {
        let singleTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapGesture(_:))
        )
        viewController.messagesCollectionView.addOrEnable(singleTapGesture)

        typealias Floats = AppConstants.CGFloats.ChatPageViewService.ContextMenu
        if let doubleTapGesture = viewController
            .messagesCollectionView
            .gestureRecognizers?
            .compactMap({ $0 as? UITapGestureRecognizer })
            .first(where: { $0.numberOfTapsRequired == Int(Floats.doubleTapGestureNumberOfTapsRequired) }) {
            singleTapGesture.require(toFail: doubleTapGesture)
        }
    }

    // MARK: - Handle Tap Gesture

    @objc
    public func handleTapGesture(_ sender: UITapGestureRecognizer) {
        let touchPoint = sender.location(in: viewController.messagesCollectionView)

        guard let indexPath = viewController.messagesCollectionView.indexPathForItem(at: touchPoint),
              let selectedCell = viewController.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell else { return }
        let convertedTouchPoint = viewController.messagesCollectionView.convert(touchPoint, to: selectedCell.messageContainerView)
        guard selectedCell.messageContainerView.bounds.contains(convertedTouchPoint) else { return }

        if let mediaCell = selectedCell as? MediaMessageCell {
            mediaMessagePreviewService?.didTapImage(in: mediaCell)
        } else if let textCell = selectedCell as? TextMessageCell {
            attributeDetectionService.handleGesture(
                in: textCell.contentView,
                label: textCell.messageLabel,
                at: convertedTouchPoint
            )
        }
    }
}
