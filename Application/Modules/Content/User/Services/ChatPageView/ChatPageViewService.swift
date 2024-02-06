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

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewControllerFactory) private var chatPageViewControllerFactory: ChatPageViewControllerFactory
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var deliveryProgression: DeliveryProgressionService?
    public private(set) var gestureRecognizer: GestureRecognizerService?
    public private(set) var inputBar: InputBarService?
    public private(set) var recordingUI: RecordingUIService?
    public private(set) var typingIndicator: TypingIndicatorService?

    private var isInstantiatingForPreview = false
    private var viewController: ChatPageViewController?

    // MARK: - Instantiate View Controller

    public func instantiateViewController(_ conversation: Conversation, forPreview: Bool) -> MessagesViewController {
        clientSession.conversation.setCurrentConversation(conversation)
        isInstantiatingForPreview = forPreview

        let viewController = chatPageViewControllerFactory.buildViewController()
        self.viewController = viewController

        let deliveryProgressionService = DeliveryProgressionService(viewController)
        deliveryProgression = deliveryProgressionService
        clientSession.registerDeliveryProgressIndicator(deliveryProgressionService)

        gestureRecognizer = .init(viewController)
        inputBar = .init(viewController)
        recordingUI = .init(viewController)
        typingIndicator = .init(viewController)

        return viewController
    }

    // MARK: - View Controller Lifecycle Handlers

    public func onViewWillAppear() {
        chatPageState.setIsPresented(true)
        toggleBuildInfoOverlay(on: false)
    }

    public func onViewDidAppear() {
        typingIndicator?.startCheckingForTypingIndicatorChanges()

        guard !isInstantiatingForPreview else {
            viewController?.messageInputBar.isHidden = true
            viewController?.messagesCollectionView.scrollToLastItem(animated: false)
            return
        }

        gestureRecognizer?.configureInputBarGestureRecognizers()
        inputBar?.configureInputBar(forceUpdate: true)
        viewController?.becomeFirstResponder()
        viewController?.messagesCollectionView.scrollToLastItem(animated: true)
    }

    public func onViewWillDisappear() {
        @Persistent(.hidesBuildInfoOverlay) var hidesBuildInfoOverlay: Bool?
        toggleBuildInfoOverlay(on: !(hidesBuildInfoOverlay ?? false))

        typingIndicator?.stopCheckingForTypingIndicatorChanges()
    }

    public func onViewDidDisappear() {
        chatPageState.setIsPresented(false)

        Task {
            if let exception = await inputBar?.textViewDidChange(to: "") {
                Logger.log(exception, with: .toast())
            }
        }

        audioService.playback.stopPlaying()
        if let exception = audioService.recording.cancelRecording() {
            guard !exception.isEqual(to: .noAudioRecorderToStop) else { return }
            Logger.log(exception, with: .toast())
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
