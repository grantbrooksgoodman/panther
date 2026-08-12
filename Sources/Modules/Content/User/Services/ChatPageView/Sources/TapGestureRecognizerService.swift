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

/// The service that manages the page's tap gesture recognizer.
///
/// ``TapGestureRecognizerService`` installs a single-tap recognizer on the message list and
/// routes each tap to the appropriate handler: presenting a failed message's action sheet,
/// previewing tapped media, or handling a detected attribute – such as a link – in tapped text.
@MainActor
final class TapGestureRecognizerService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.attributeDetection) private var attributeDetectionService: AttributeDetectionService
    @Dependency(\.chatPageViewService.mediaMessagePreview) private var mediaMessagePreviewService: MediaMessagePreviewService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Configure Gesture Recognizer

    /// Installs the single-tap recognizer on the message list.
    ///
    /// The recognizer is configured to require the message list's double-tap recognizer to fail
    /// first, so a double tap does not also register as a single tap.
    func configureGestureRecognizer() {
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
            .first(where: {
                $0.numberOfTapsRequired == Int(Floats.doubleTapGestureNumberOfTapsRequired)
            }) {
            singleTapGesture.require(toFail: doubleTapGesture)
        }
    }

    // MARK: - Handle Tap Gesture

    /// Handles a tap on the message list.
    ///
    /// When the tap lands within a message's content, this method presents the failed message
    /// action sheet for a failed outbox message, previews the tapped media, or handles a
    /// detected attribute in tapped text. Taps outside message content are ignored.
    ///
    /// - Parameter sender: The tap gesture recognizer that recognized the tap.
    @objc
    func handleTapGesture(_ sender: UITapGestureRecognizer) {
        let touchPoint = sender.location(in: viewController.messagesCollectionView)

        guard let indexPath = viewController.messagesCollectionView.indexPathForItem(at: touchPoint),
              let selectedCell = viewController.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell else { return }
        let convertedTouchPoint = viewController.messagesCollectionView.convert(touchPoint, to: selectedCell.messageContainerView)
        guard selectedCell.messageContainerView.bounds.contains(convertedTouchPoint) else { return }

        let message = viewController.displayedMessages.itemAt(indexPath.section)
        if let message,
           message.isFailedOutboxMessage {
            viewController.presentFailedMessageActionSheet(
                forMessageID: message.id,
                sourceView: selectedCell.messageContainerView
            )
        } else if let mediaCell = selectedCell as? MediaMessageCell {
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
