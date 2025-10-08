//
//  MediaMessagePreviewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

public final class MediaMessagePreviewService {
    // MARK: - Types

    public enum CacheKey: String, CaseIterable {
        case images
        case thumbnails
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.quickViewer) private var quickViewer: QuickViewer
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    @Cached(CacheKey.images) public var cachedImages: [URL: UIImage]?
    @Cached(CacheKey.thumbnails) public var cachedThumbnails: [URL: UIImage]?

    public private(set) var isPreviewingMedia = false

    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    private var mediaPaths: [String] {
        viewController
            .currentConversation?
            .messages?
            .compactMap { $0.richContent?.mediaComponent?.localPathURL.path() } ?? []
    }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Configure Gesture Recognizers

    public func configureGestureRecognizers() {
        let pinchGestureRecognizer: UIPinchGestureRecognizer = .init(
            target: self,
            action: #selector(pinchGestureRecognized)
        )
        viewController.messagesCollectionView.addOrEnable(pinchGestureRecognizer)
    }

    // MARK: - Did Tap Image

    public func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
              let message = viewController.currentConversation?.messages?.itemAt(indexPath.section),
              message.contentType.isMedia,
              let filePath = message.richContent?.mediaComponent?.localPathURL.path(),
              fileManager.fileExists(atPath: filePath),
              !isPreviewingMedia,
              let contextMenuService = chatPageViewService.contextMenu,
              !contextMenuService.interaction.isPresentingContextMenu else { return }

        let inputBarWasFirstResponder = chatPageViewService.inputBar?.isFirstResponder ?? false
        let recipientBarWasFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false
        uiApplication.resignFirstResponders()

        InteractivePopGestureRecognizer.setIsEnabled(false)
        if let exception = quickViewer.preview(
            filesAtPaths: mediaPaths,
            startingIndex: mediaPaths.firstIndex(of: filePath) ?? 0,
            title: Localized(.attachment).wrappedValue.lowercased()
        ) {
            return Logger.log(exception)
        }

        quickViewer.onDismiss {
            self.chatPageViewService.redrawForAppearanceChange()
            self.isPreviewingMedia = false

            if inputBarWasFirstResponder {
                self.chatPageViewService.inputBar?.becomeFirstResponder()
            } else if recipientBarWasFirstResponder {
                self.chatPageViewService.recipientBar?.layout.textField?.becomeFirstResponder()
            }

            self.enableUserInteraction()
        }

        isPreviewingMedia = true
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cachedImages = nil
        cachedThumbnails = nil
    }

    // MARK: - Auxiliary

    /// - NOTE: Fixes a bug in which a dismissal of the `QuickViewer` would cause the view's user interaction to become disabled.
    private func enableUserInteraction() {
        Logger.log(
            "Intercepted QuickViewer dismissal user interaction bug.",
            domain: .bugPrevention,
            metadata: [self, #file, #function, #line]
        )

        InteractivePopGestureRecognizer.setIsEnabled(true)
        viewController.view.isUserInteractionEnabled = true

        coreGCD.after(.seconds(1)) { self.viewController.view.isUserInteractionEnabled = true }
        coreGCD.after(.seconds(2)) { self.viewController.view.isUserInteractionEnabled = true }
        coreGCD.after(.seconds(3)) { self.viewController.view.isUserInteractionEnabled = true }
    }

    @objc
    private func pinchGestureRecognized(recognizer: UIPinchGestureRecognizer) {
        let touchPoint = recognizer.location(in: viewController.messagesCollectionView)

        guard let indexPath = viewController.messagesCollectionView.indexPathForItem(at: touchPoint),
              let selectedCell = viewController.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell else { return }

        let convertedTouchPoint = viewController.messagesCollectionView.convert(touchPoint, to: selectedCell.messageContainerView)
        guard selectedCell.messageContainerView.bounds.contains(convertedTouchPoint) else { return }

        didTapImage(in: selectedCell)
    }
}
