//
//  SearchInteractionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

final class SearchInteractionService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService.contextMenu?.interaction) private var contextMenuInteractionService: ContextMenuInteractionService?
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.chatPageStateService.isPresented) private var isChatPagePresented: Bool
    @Dependency(\.clientSession.conversation.currentConversation?.messages) private var messages: [Message]?

    // MARK: - Properties

    private let focusedMessageID: String?
    private let viewController: ChatPageViewController

    private var hasTriggeredInteractionOnce = false

    // MARK: - Computed Properties

    private var focusedMessageCellGestureRecognizer: UILongPressGestureRecognizer? {
        guard let focusedMessageIndex = messages?.firstIndex(where: { $0.id == focusedMessageID }) else { return nil }
        return viewController
            .messagesCollectionView
            .cellForItem(at: .init(item: 0, section: focusedMessageIndex))?
            .traversedSubviews
            .compactMap(\.gestureRecognizers)
            .reduce([], +)
            .compactMap { $0 as? UILongPressGestureRecognizer }
            .first(where: { $0.minimumPressDuration == 0.22 })
    }

    // MARK: - Init

    init(
        _ viewController: ChatPageViewController,
        focusedMessageID: String?
    ) {
        self.viewController = viewController
        self.focusedMessageID = focusedMessageID
    }

    // MARK: - Trigger Focused Message Cell Interaction

    @MainActor
    func triggerFocusedMessageCellInteractionIfNeeded() {
        guard isChatPagePresented,
              !hasTriggeredInteractionOnce else { return }

        contextMenuInteractionService?.removeUIMenuLongPressGestureForVisibleCells()
        contextMenuInteractionService?.addContextMenuInteractionToVisibleCellsOnce()

        triggerCellInteraction()
    }

    @MainActor
    private func triggerCellInteraction(_ retryOnFailure: Bool = true) {
        guard isChatPagePresented,
              let focusedMessageCellGestureRecognizer else {
            guard retryOnFailure else { return }
            coreGCD.after(.milliseconds(500)) { self.triggerCellInteraction(false) }
            return
        }

        focusedMessageCellGestureRecognizer.state = .began
        ContextMenuInteractor.shared.beginInteraction(focusedMessageCellGestureRecognizer)
        hasTriggeredInteractionOnce = true
    }
}
