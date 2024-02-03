//
//  ChatPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public final class ChatPageViewService {
    // MARK: - Properties

    public private(set) var deliveryProgression: DeliveryProgressionService?

    private var viewController: ChatPageViewController?

    // MARK: - Instantiate View Controller

    public func instantiateViewController(_ conversation: Conversation) -> MessagesViewController {
        @Dependency(\.chatPageViewControllerFactory) var chatPageViewControllerFactory: ChatPageViewControllerFactory
        @Dependency(\.clientSession.conversation) var conversationSession: ConversationSessionService

        conversationSession.setCurrentConversation(conversation)

        let viewController = chatPageViewControllerFactory.buildViewController()
        self.viewController = viewController
        deliveryProgression = .init(viewController)

        return viewController
    }

    // MARK: - Auxiliary

    public func reloadCollectionView() {
        Task { @MainActor in
            viewController?.messagesCollectionView.reloadDataAndKeepOffset()
        }
    }
}
