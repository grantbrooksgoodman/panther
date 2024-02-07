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
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var audioMessagePlayback: AudioMessagePlaybackService?
    public private(set) var deliveryProgressIndicator: DeliveryProgressIndicatorService?
    public private(set) var gestureRecognizer: GestureRecognizerService?
    public private(set) var inputBar: InputBarService?
    public private(set) var messageDelivery: MessageDeliveryService?
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

        let deliveryProgressIndicatorService = DeliveryProgressIndicatorService(viewController)
        deliveryProgressIndicator = deliveryProgressIndicatorService
        clientSession.registerDeliveryProgressIndicator(deliveryProgressIndicatorService)

        audioMessagePlayback = .init(viewController)
        gestureRecognizer = .init(viewController)
        inputBar = .init(viewController)
        messageDelivery = .init(viewController)
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
            core.gcd.after(.milliseconds(10)) { self.viewController?.messagesCollectionView.scrollToLastItem(animated: false) }
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

    // MARK: - UITraitCollection

    public func onTraitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard previousTraitCollection?.userInterfaceStyle != viewController?.traitCollection.userInterfaceStyle else { return }
        viewController?.messageInputBar.backgroundView.backgroundColor = .inputBarBackground
        core.ui.setNavigationBarAppearance(backgroundColor: .navigationBarBackground, titleColor: .navigationBarTitle)
        viewController?.navigationController?.isNavigationBarHidden = true
        viewController?.navigationController?.isNavigationBarHidden = false
        reloadCollectionView()
    }

    // MARK: - Auxiliary

    public func reloadCollectionView() {
        Task { @MainActor in
            guard !audioService.playback.isPlaying else {
                audioService.playback.onFailedToFinishPlaying { self.reloadCollectionView() }
                audioService.playback.onFinishedPlaying { self.reloadCollectionView() }
                audioService.playback.onStopPlaying { self.reloadCollectionView() }
                return
            }

            viewController?.messagesCollectionView.reloadDataAndKeepOffset()
        }
    }

    private func toggleBuildInfoOverlay(on: Bool) {
        guard let overlayWindow = uiApplication.keyWindow?.firstSubview(for: "BUILD_INFO_OVERLAY_WINDOW") as? UIWindow else { return }
        overlayWindow.isHidden = !on
    }
}
