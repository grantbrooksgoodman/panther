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

@MainActor
final class ReadReceiptService {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Update Read Date for Unread Messages

    func updateReadDateForUnreadMessages() async throws(Exception) {
        guard let conversation = clientSession.conversation.currentConversation,
              let messages = conversation.messages?.filter({ !$0.isFromCurrentUser }),
              messages.last?.currentUserReadReceipt == nil else { return }

        let unreadMessages = messages.filter { $0.currentUserReadReceipt == nil }
        guard !unreadMessages.isEmpty else { return }

        try await conversation.updateReadDate(
            for: unreadMessages
        )

        if let currentUser = clientSession.user.currentUser {
            try await notificationService.setBadgeNumber(
                currentUser.calculateBadgeNumber()
            )
        }

        // NIT: May no longer be necessary.
        if clientSession.conversation.currentConversation?.id.key == conversation.id.key {
            clientSession.conversation.setCurrentConversation(conversation)
        }
    }
}
