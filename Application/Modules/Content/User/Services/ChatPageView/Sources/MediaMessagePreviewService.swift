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

/* 3rd-party */
import CoreArchitecture
import MessageKit

public final class MediaMessagePreviewService {
    // MARK: - Types

    public enum CacheKey: String, CaseIterable {
        case images
        case thumbnails
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.quickViewer) private var quickViewer: QuickViewer

    // MARK: - Properties

    public let cache: Cache<CacheKey> = .init()
    public private(set) var isPreviewingMedia = false
    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    private var mediaPaths: [String] {
        viewController
            .currentConversation?
            .messages?
            .compactMap { $0.richContent?.mediaComponent?.urlPath.path() } ?? []
    }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Configure Gesture Recognizer

    public func configureGestureRecognizer() {
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
              message.contentType == .media,
              let filePath = message.richContent?.mediaComponent?.urlPath.path(),
              fileManager.fileExists(atPath: filePath),
              !isPreviewingMedia else { return }

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
        }

        isPreviewingMedia = true
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cache.clear()
    }

    // MARK: - Auxiliary

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
