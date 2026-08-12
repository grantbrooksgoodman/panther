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

/// The service that manages media message previews.
///
/// ``MediaMessagePreviewService`` presents a full-screen viewer for a tapped media message,
/// letting the user page through all of the conversation's media. It also caches decoded images
/// and thumbnails for reuse.
///
/// - Note: While a preview is presented, ``isPreviewingMedia`` is `true`; the chat page uses
///   this to distinguish being covered by the preview from being dismissed.
@MainActor
final class MediaMessagePreviewService {
    // MARK: - Types

    /// The keys identifying the service's media caches.
    enum CacheKey: String, CaseIterable {
        /// The cache of full-size images.
        case images

        /// The cache of thumbnail images.
        case thumbnails
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.quickViewer) private var quickViewer: QuickViewer
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    /// The cache of full-size images, keyed by local file URL.
    @Cached(CacheKey.images) var cachedImages: [URL: UIImage]?

    /// The cache of thumbnail images, keyed by local file URL.
    @Cached(CacheKey.thumbnails) var cachedThumbnails: [URL: UIImage]?

    /// A Boolean value that indicates whether a media preview is currently presented.
    private(set) var isPreviewingMedia = false

    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    private var mediaPaths: [String] {
        viewController
            .displayedMessages
            .compactMap { $0.richContent?.mediaComponent?.localPathURL.path() }
    }

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Configure Gesture Recognizers

    /// Installs the pinch recognizer that opens the media preview on the message list.
    func configureGestureRecognizers() {
        let pinchGestureRecognizer: UIPinchGestureRecognizer = .init(
            target: self,
            action: #selector(pinchGestureRecognized)
        )
        viewController.messagesCollectionView.addOrEnable(pinchGestureRecognizer)
    }

    // MARK: - Did Tap Image

    /// Presents the media preview for the media in the given cell.
    ///
    /// This method dismisses the keyboard and opens a full-screen viewer showing all of the
    /// conversation's media, starting at the tapped item. When the viewer is dismissed, it
    /// redraws the page and restores first responder status to whichever input field held it.
    ///
    /// This method has no effect when the cell holds no downloaded media, when a preview is
    /// already presented, or when a context menu is presented.
    ///
    /// - Parameter cell: The cell whose media to preview.
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
              let message = viewController.displayedMessages.itemAt(indexPath.section),
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

        do {
            try quickViewer.preview(
                filesAtPaths: mediaPaths,
                startingIndex: mediaPaths.firstIndex(of: filePath) ?? 0,
                title: Localized(.attachment).wrappedValue.lowercased()
            )
        } catch {
            return Logger.log(error)
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

    /// Removes every cached image and thumbnail.
    func clearCache() {
        cachedImages = nil
        cachedThumbnails = nil
    }

    // MARK: - Auxiliary

    /// - NOTE: Fixes a bug in which a dismissal of the `QuickViewer` would cause the view's user interaction to become disabled.
    private func enableUserInteraction() {
        Logger.log(
            "Intercepted QuickViewer dismissal user interaction bug.",
            domain: .bugPrevention,
            sender: self
        )

        InteractivePopGestureRecognizer.setIsEnabled(true)
        viewController.view.isUserInteractionEnabled = true

        Task.delayed(by: .seconds(1)) { @MainActor [weak self] in
            self?.viewController.view.isUserInteractionEnabled = true
        }

        Task.delayed(by: .seconds(2)) { @MainActor [weak self] in
            self?.viewController.view.isUserInteractionEnabled = true
        }

        Task.delayed(by: .seconds(3)) { @MainActor [weak self] in
            self?.viewController.view.isUserInteractionEnabled = true
        }
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
