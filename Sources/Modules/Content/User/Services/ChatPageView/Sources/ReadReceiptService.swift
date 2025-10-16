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

public final class ReadReceiptService {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Update Read Date for Unread Messages

    public func updateReadDateForUnreadMessages() async -> Exception? {
        guard let conversation = clientSession.conversation.fullConversation,
              let messages = conversation.messages?.filter({ !$0.isFromCurrentUser }),
              messages.last?.currentUserReadReceipt == nil else { return nil }

        let unreadMessages = messages.filter { $0.currentUserReadReceipt == nil }
        guard !unreadMessages.isEmpty else { return nil }

        clientSession.user.stopObservingCurrentUserChanges()
        let updateReadDateResult = await conversation.updateReadDate(for: unreadMessages)
        clientSession.user.startObservingCurrentUserChanges()

        switch updateReadDateResult {
        case let .success(conversation):
            Logger.log(
                "Updated read date for \(unreadMessages.count) message\(unreadMessages.count == 1 ? "" : "s").",
                domain: .conversation,
                sender: self
            )

            if let currentUser = clientSession.user.currentUser,
               let exception = await notificationService.setBadgeNumber(currentUser.calculateBadgeNumber() - unreadMessages.count) {
                return exception
            }

            if clientSession.conversation.currentConversation?.id.key == conversation.id.key {
                clientSession.conversation.setCurrentConversation(conversation)
            }

            return nil

        case let .failure(exception):
            return exception
        }
    }
}
