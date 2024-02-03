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
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.inputBarAccessoryViewService) private var inputBarAccessoryViewService: InputBarAccessoryViewService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var deliveryProgression: DeliveryProgressionService?
    public private(set) var recordingUI: RecordingUIService?
    public private(set) var typingIndicator: TypingIndicatorService?

    private var viewController: ChatPageViewController?

    // MARK: - Instantiate View Controller

    public func instantiateViewController(_ conversation: Conversation) -> MessagesViewController {
        @Dependency(\.chatPageViewControllerFactory) var chatPageViewControllerFactory: ChatPageViewControllerFactory
        @Dependency(\.clientSession.conversation) var conversationSession: ConversationSessionService

        conversationSession.setCurrentConversation(conversation)

        let viewController = chatPageViewControllerFactory.buildViewController()
        self.viewController = viewController
        deliveryProgression = .init(viewController)
        typingIndicator = .init(viewController)
        recordingUI = .init(viewController)

        return viewController
    }

    // MARK: - View Controller Lifecycle Handlers

    public func onViewWillAppear() {
        toggleBuildInfoOverlay(on: false)
    }

    public func onViewDidAppear() {
        chatPageState.setIsPresented(true)
        viewController?.messagesCollectionView.scrollToLastItem(animated: true)
        typingIndicator?.startCheckingForTypingIndicatorChanges()
    }

    public func onViewWillDisappear() {
        @Persistent(.hidesBuildInfoOverlay) var hidesBuildInfoOverlay: Bool?
        toggleBuildInfoOverlay(on: !(hidesBuildInfoOverlay ?? false))

        typingIndicator?.stopCheckingForTypingIndicatorChanges()
    }

    public func onViewDidDisappear() {
        chatPageState.setIsPresented(false)
        Task {
            if let exception = await inputBarAccessoryViewService.textViewDidChange(to: "") {
                Logger.log(exception, with: .toast())
            }
        }
    }

    // MARK: - Auxiliary

    public func reloadCollectionView() {
        Task { @MainActor in
            viewController?.messagesCollectionView.reloadDataAndKeepOffset()
        }
    }

    private func toggleBuildInfoOverlay(on: Bool) {
        guard let overlayWindow = uiApplication.keyWindow?.firstSubview(for: "BUILD_INFO_OVERLAY_WINDOW") as? UIWindow else { return }
        overlayWindow.isHidden = !on
    }
}
