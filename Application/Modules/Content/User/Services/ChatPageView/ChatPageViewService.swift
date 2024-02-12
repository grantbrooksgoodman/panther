//
//  ChatPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public final class ChatPageViewService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService
    private typealias Strings = AppConstants.Strings.ChatPageViewService

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewControllerFactory) private var chatPageViewControllerFactory: ChatPageViewControllerFactory
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var alternateMessage: AlternateMessageService?
    public private(set) var audioMessagePlayback: AudioMessagePlaybackService?
    public private(set) var deliveryProgressIndicator: DeliveryProgressIndicatorService?
    public private(set) var inputBar: InputBarService?
    public private(set) var inputBarGestureRecognizer: InputBarGestureRecognizerService?
    public private(set) var menu: MenuService?
    public private(set) var messageDelivery: MessageDeliveryService?
    public private(set) var recordingUI: RecordingUIService?
    public private(set) var typingIndicator: TypingIndicatorService?

    private var configuration: ChatPageView.Configuration = .default
    private var viewController: ChatPageViewController?

    // MARK: - Instantiate View Controller

    public func instantiateViewController(_ conversation: Conversation, configuration: ChatPageView.Configuration) -> MessagesViewController {
        clientSession.conversation.resetMessageOffset()
        clientSession.conversation.setCurrentConversation(conversation)

        self.configuration = configuration
        let viewController = chatPageViewControllerFactory.buildViewController(configuration)
        self.viewController = viewController

        let deliveryProgressIndicatorService = DeliveryProgressIndicatorService(viewController)
        deliveryProgressIndicator = deliveryProgressIndicatorService
        clientSession.registerDeliveryProgressIndicator(deliveryProgressIndicatorService)

        alternateMessage = .init(viewController)
        audioMessagePlayback = .init(viewController)
        inputBar = .init(viewController)
        inputBarGestureRecognizer = .init(viewController)
        menu = .init(viewController)
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

        guard configuration != .preview else {
            viewController?.messageInputBar.isHidden = true
            core.gcd.after(.milliseconds(Floats.scrollToLastItemMillisecondsDelay)) {
                self.viewController?.messagesCollectionView.scrollToLastItem(animated: false)
            }
            return
        }

        inputBarGestureRecognizer?.configureInputBarGestureRecognizers()
        inputBar?.configureInputBar(forceUpdate: true)
        menu?.configureMenuGestureRecognizer()

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

        alternateMessage?.restoreAllAlternateTextMessageIDs()
        alternateMessage?.restoreAllAudioTranscriptionMessageIDs()

        avSpeechSynthesizer.stopSpeaking(at: .immediate)
        audioService.playback.stopPlaying()
        if let exception = audioService.recording.cancelRecording() {
            guard !exception.isEqual(to: .noAudioRecorderToStop) else { return }
            Logger.log(exception, with: .toast())
        }
    }

    // MARK: - UIScrollView

    public func onScrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.panGestureRecognizer.translation(in: scrollView.superview).y > 0 else { return }
        loadMoreMessages(fromScrollToTop: false)
    }

    public func onScrollViewDidScrollToTop() {
        loadMoreMessages(fromScrollToTop: true)
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
            viewController?.messagesCollectionView.reloadDataAndKeepOffset()
        }
    }

    public func reloadItemsWhenSafe(at indexPaths: [IndexPath]) {
        func reloadItems() {
            Task { @MainActor in
                viewController?.messagesCollectionView.reloadItems(at: indexPaths)
            }
        }

        guard let messageDelivery,
              messageDelivery.isSendingMessage else {
            reloadItems()
            return
        }

        messageDelivery.addEffectUponIsSendingMessage(changedTo: false, id: .reloadCollectionView) { reloadItems() }
    }

    private func loadMoreMessages(fromScrollToTop: Bool) {
        guard !(messageDelivery?.isSendingMessage ?? false) else { return }

        let previousMessageCount = clientSession.conversation.currentConversation?.messages?.count
        clientSession.conversation.incrementMessageOffset()
        guard previousMessageCount != clientSession.conversation.currentConversation?.messages?.count else { return }
        reloadCollectionView()

        guard fromScrollToTop else { return }
        core.gcd.after(.milliseconds(Floats.loadMoreMessagesMillisecondsDelay)) {
            self.viewController?.messagesCollectionView.scrollToItem(
                at: .init(row: 0, section: 0),
                at: .top,
                animated: true
            )
        }
    }

    private func toggleBuildInfoOverlay(on: Bool) {
        guard let overlayWindow = uiApplication.keyWindow?.firstSubview(for: Strings.buildInfoOverlayWindowSemanticTag) as? UIWindow else { return }
        overlayWindow.isHidden = !on
    }
}
