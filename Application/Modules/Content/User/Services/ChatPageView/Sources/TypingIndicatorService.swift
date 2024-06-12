//
//  TypingIndicatorService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class TypingIndicatorService {
    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var typingIndicatorTimer: Timer?

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Object Lifecycle

    deinit {
        stopCheckingForTypingIndicatorChanges()
    }

    // MARK: - Public

    public func startCheckingForTypingIndicatorChanges() {
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.TypingIndicator
        typingIndicatorTimer = .scheduledTimer(
            timeInterval: .init(Floats.timerTimeInterval),
            target: self,
            selector: #selector(checkForTypingIndicatorChanges),
            userInfo: nil,
            repeats: true
        )
    }

    public func stopCheckingForTypingIndicatorChanges() {
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
    }

    // MARK: - Auxiliary

    @objc
    private func checkForTypingIndicatorChanges() {
        // TODO: Ensure not waiting to update conversation – if about to add a message, NSInternalInconsistencyException.
        @Persistent(.currentUserID) var currentUserID: String?
        guard let conversation = viewController.currentConversation,
              conversation.participants.filter({ $0.userID != currentUserID }).contains(where: { $0.isTyping }) else {
            guard !viewController.isTypingIndicatorHidden else { return }
            viewController.setTypingIndicatorViewHidden(true, animated: true)
            return
        }

        guard viewController.isTypingIndicatorHidden else { return }
        viewController.setTypingIndicatorViewHidden(false, animated: true)
        viewController.messagesCollectionView.scrollToLastItem(animated: true)
    }
}
