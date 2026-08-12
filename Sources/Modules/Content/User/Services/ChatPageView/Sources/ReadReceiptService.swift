//
//  ReadReceiptService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// The service that manages read receipts.
///
/// ``ReadReceiptService`` marks the displayed conversation's incoming messages as read and keeps
/// the application badge in sync with the resulting unread count.
@MainActor
final class ReadReceiptService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Update Read Date for Unread Messages

    /// Marks the displayed conversation's unread incoming messages as read, then updates the
    /// application badge.
    ///
    /// This method has no effect when the most recent incoming message has already been read, or
    /// when there are no unread incoming messages.
    ///
    /// - Throws: An `Exception` if updating the read dates or the badge number fails.
    func updateReadDateForUnreadMessages() async throws(Exception) {
        guard let conversation = entitySession.conversation.currentConversation,
              let messages = conversation.messages?.filter({ !$0.isFromCurrentUser }),
              messages.last?.currentUserReadReceipt == nil else { return }

        let unreadMessages = messages.filter { $0.currentUserReadReceipt == nil }
        guard !unreadMessages.isEmpty else { return }

        try await conversation.updateReadDate(
            for: unreadMessages
        )

        if let currentUser = entitySession.user.currentUser {
            try await notificationService.setBadgeNumber(
                currentUser.calculateBadgeNumber()
            )
        }
    }
}
