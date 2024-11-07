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

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

public final class ChatPageViewService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService
    private typealias Strings = AppConstants.Strings.ChatPageViewService

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.build) private var build: Build
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewControllerFactory) private var chatPageViewControllerFactory: ChatPageViewControllerFactory
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var alternateMessage: AlternateMessageService?
    public private(set) var audioMessagePlayback: AudioMessagePlaybackService?
    public private(set) var contextMenu: ContextMenuService?
    public private(set) var deliveryProgressIndicator: DeliveryProgressIndicatorService?
    public private(set) var inputBar: InputBarService?
    public private(set) var inputBarGestureRecognizer: InputBarGestureRecognizerService?
    public private(set) var mediaActionHandler: MediaActionHandlerService?
    public private(set) var mediaMessagePreview: MediaMessagePreviewService?
    public private(set) var readDate: ReadDateService?
    public private(set) var recipientBar: RecipientBarService?
    public private(set) var recordingUI: RecordingUIService?
    public private(set) var tapGestureRecognizer: TapGestureRecognizerService?
    public private(set) var typingIndicator: TypingIndicatorService?

    private var configuration: ChatPageView.Configuration = .default
    private var viewController: ChatPageViewController?

    // MARK: - Instantiate View Controller

    public func instantiateViewController(_ conversation: Conversation, configuration: ChatPageView.Configuration) -> MessagesViewController {
        clientSession.conversation.resetMessageOffset()
        clientSession.conversation.setCurrentConversation(conversation)

        self.configuration = configuration
        let viewController = chatPageViewControllerFactory.buildViewController()
        self.viewController = viewController

        let deliveryProgressIndicatorService = DeliveryProgressIndicatorService(viewController)
        deliveryProgressIndicator = deliveryProgressIndicatorService
        clientSession.registerDeliveryProgressIndicator(deliveryProgressIndicatorService)

        alternateMessage = .init(viewController)
        audioMessagePlayback = .init(viewController)
        contextMenu = .init(viewController)
        inputBar = .init(viewController)
        inputBarGestureRecognizer = .init(viewController)
        mediaActionHandler = .init(viewController)
        mediaMessagePreview = .init(viewController)
        readDate = .init(viewController)
        recordingUI = .init(viewController)
        tapGestureRecognizer = .init(viewController)
        typingIndicator = .init(viewController)

        guard configuration == .newChat else { return viewController }

        let recipientBarService = RecipientBarService(viewController)
        recipientBar = recipientBarService
        chatPageViewControllerFactory.configureRecipientBar(viewController, service: recipientBarService)

        return viewController
    }

    // MARK: - View Controller Lifecycle Handlers

    public func onViewWillAppear() {
        guard !(mediaActionHandler?.isPresentingPickerController ?? false),
              !(mediaMessagePreview?.isPreviewingMedia ?? false) else { return }

        modifyConfigurationIfNeeded()
        chatPageState.setIsPresented(true)
        toggleBuildInfoOverlay(on: false)

        if configuration == .newChat {
            viewController?.messageInputBar.inputTextView.placeholder = ""
        }

        viewController?.messageInputBar.alpha = configuration == .default ? 0 : 1
    }

    public func onViewDidAppear() {
        guard !(mediaActionHandler?.isPresentingPickerController ?? false),
              !(mediaMessagePreview?.isPreviewingMedia ?? false) else { return }

        typingIndicator?.startCheckingForTypingIndicatorChanges()
        InteractivePopGestureRecognizer.setIsEnabled(true)

        guard configuration != .preview else {
            viewController?.messageInputBar.isHidden = true
            core.gcd.after(.milliseconds(Floats.scrollToLastItemDelayMilliseconds)) {
                self.viewController?.messagesCollectionView.scrollToLastItem(animated: false)
            }
            return
        }

        contextMenu?.interaction.addKeyboardWillShowObserver()
        contextMenu?.interaction.startAddingContextMenuInteractionToVisibleCells()

        contextMenu?.interaction.configureDoubleTapGestureRecognizer()
        mediaMessagePreview?.configureGestureRecognizers()
        inputBarGestureRecognizer?.configureGestureRecognizers()
        tapGestureRecognizer?.configureGestureRecognizer()

        inputBar?.configureInputBar(forceUpdate: true)
        inputBar?.toggleSendingUI(on: messageDeliveryService.isSendingMessage)

        if configuration == .default {
            services.analytics.logEvent(.accessChat)
            inputBar?.becomeFirstResponder()
            uiApplication.resignFirstResponders()

            UIView.animate(
                withDuration: Floats.inputBarAppearanceAnimationDuration,
                delay: Floats.inputBarAppearanceAnimationDuration
            ) {
                self.viewController?.messageInputBar.alpha = 1
            }
        }

        services.connectionStatus.addEffectUponConnectionChanged(id: .configureInputBar) {
            self.inputBar?.configureInputBar(forceUpdate: true)
        }

        Task {
            if let exception = await readDate?.updateReadDateForUnreadMessages() {
                Logger.log(exception, with: .toast())
            }

            if let exception = await typingIndicator?.textViewDidChange(to: "") {
                Logger.log(exception, with: .toast())
            }
        }

        viewController?.becomeFirstResponder()
    }

    public func onViewWillDisappear() {
        guard !(mediaActionHandler?.isPresentingPickerController ?? false),
              !(mediaMessagePreview?.isPreviewingMedia ?? false) else { return }

        NavigationBar.setAppearance(.appDefault)
        toggleBuildInfoOverlay(on: true)

        contextMenu?.interaction.stopAddingContextMenuInteractionToVisibleCells()
        typingIndicator?.stopCheckingForTypingIndicatorChanges()
    }

    public func onViewDidDisappear() {
        guard !(mediaActionHandler?.isPresentingPickerController ?? false),
              !(mediaMessagePreview?.isPreviewingMedia ?? false) else { return }

        chatPageState.setIsPresented(false)
        contextMenu?.interaction.removeKeyboardWillShowObserver()

        Task.background {
            if let exception = await typingIndicator?.textViewDidChange(to: "") {
                Logger.log(exception)
            }

            // TODO: Audit this.
            // clientSession.conversation.setCurrentConversation(nil)
            clientSession.conversation.resetMessageOffset()
        }

        alternateMessage?.restoreAllAlternateTextMessageIDs()
        alternateMessage?.restoreAllAudioTranscriptionMessageIDs()

        services.connectionStatus.removeEffect(.configureInputBar)

        avSpeechSynthesizer.stopSpeaking(at: .immediate)
        audioMessagePlayback?.stopPlayback()
        if let exception = services.audio.recording.cancelRecording() {
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
        redrawForAppearanceChange()
    }

    // MARK: - Auxiliary

    public func redrawForAppearanceChange() {
        Task { @MainActor in
            inputBar?.configureInputBar(forceUpdate: true)
            inputBar?.setAttachMediaButtonImage()
            recipientBar?.layout.layoutSubviews()
            recipientBar?.contactSelectionUI.unhighlightAllViews()
            NavigationBar.setAppearance(configuration == .newChat ? .themed(showsDivider: false) : .appDefault)
            StatusBarStyle.restore()
            UIView.dismissCurrentContextMenu()
            viewController?.navigationController?.isNavigationBarHidden = true
            viewController?.navigationController?.isNavigationBarHidden = false
            reloadCollectionView()
        }
    }

    public func reloadCollectionView() {
        Task { @MainActor in
            guard viewController?.currentConversation?.messages?.count == 1 else { return viewController?.messagesCollectionView.reloadDataAndKeepOffset() }
            viewController?.messagesCollectionView.reloadData()
        }
    }

    public func reloadItemsWhenSafe(at indexPaths: [IndexPath]) {
        func reloadItems() {
            Task { @MainActor in
                guard let viewController else { return }
                let indexPaths = indexPaths.filter { !viewController.isSectionReservedForTypingIndicator($0.section) }
                guard !indexPaths.isEmpty else { return }
                viewController.messagesCollectionView.reloadItems(at: indexPaths)
            }
        }

        if clientSession.reaction.isReactingToMessage {
            clientSession.reaction.addEffectUponIsReactingToMessage(changedTo: false, id: .reloadCollectionView) { self.reloadItemsWhenSafe(at: indexPaths) }
        } else if messageDeliveryService.isSendingMessage {
            messageDeliveryService.addEffectUponIsSendingMessage(changedTo: false, id: .reloadCollectionView) { self.reloadItemsWhenSafe(at: indexPaths) }
        } else {
            reloadItems()
        }
    }

    public func setNavigationTitle(_ navigationTitle: String) {
        Task { @MainActor in
            guard let parent = viewController?.parent else { return }
            parent.navigationItem.title = navigationTitle
        }
    }

    private func loadMoreMessages(fromScrollToTop: Bool) {
        guard !messageDeliveryService.isSendingMessage else { return }

        let previousMessageCount = clientSession.conversation.currentConversation?.messages?.count
        clientSession.conversation.incrementMessageOffset()
        guard previousMessageCount != clientSession.conversation.currentConversation?.messages?.count else { return }
        reloadCollectionView()

        guard fromScrollToTop else { return }
        core.gcd.after(.milliseconds(Floats.loadMoreMessagesDelayMilliseconds)) {
            guard let viewController = self.viewController,
                  viewController.messagesCollectionView.numberOfSections > 0 else { return }
            viewController.messagesCollectionView.scrollToItem(
                at: .init(row: 0, section: 0),
                at: .top,
                animated: true
            )
        }
    }

    /// - NOTE: Fixes a bug in which a recent dismissal of the chat page would cause the next preview to incorrectly use the `.default` configuration.
    private func modifyConfigurationIfNeeded() {
        let presentedViewControllerIDs = uiApplication.presentedViewControllers.map { String(type(of: $0.self)) }
        guard presentedViewControllerIDs.contains(Strings.chatPageViewPreviewViewControllerID),
              presentedViewControllerIDs.contains(Strings.editingOverlayViewControllerID),
              presentedViewControllerIDs.contains(Strings.inputWindowControllerID),
              presentedViewControllerIDs.count(of: Strings.navigationStackHostingControllerID) != 2,
              configuration != .preview else { return }

        Logger.log(
            "Intercepted misconfigured preview bug.",
            domain: .bugPrevention,
            metadata: [self, #file, #function, #line]
        )

        configuration = .preview
    }

    private func toggleBuildInfoOverlay(on: Bool) {
        @Persistent(.init("hidesBuildInfoOverlay")) var hidesBuildInfoOverlay: Bool?
        guard build.milestone != .generalRelease,
              !(hidesBuildInfoOverlay ?? false) else { return }

        switch !on {
        case true: BuildInfoOverlay.hide(persistSetting: false)
        case false: BuildInfoOverlay.show(persistSetting: false)
        }
    }
}
