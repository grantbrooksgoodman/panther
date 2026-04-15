//
//  ChatPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import AVFAudio
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

@MainActor
final class ChatPageViewService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService
    private typealias Strings = AppConstants.Strings.ChatPageViewService

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.build) private var build: Build
    @Dependency(\.chatInfoPageViewService) private var chatInfoPageViewService: ChatInfoPageViewService
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewControllerFactory) private var chatPageViewControllerFactory: ChatPageViewControllerFactory
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    private(set) var alternateMessage: AlternateMessageService?
    private(set) var audioMessagePlayback: AudioMessagePlaybackService?
    private(set) var contextMenu: ContextMenuService?
    private(set) var deliveryProgressIndicator: DeliveryProgressIndicatorService?
    private(set) var inputBar: InputBarService?
    private(set) var inputBarGestureRecognizer: InputBarGestureRecognizerService?
    private(set) var mediaActionHandler: MediaActionHandlerService?
    private(set) var mediaMessagePreview: MediaMessagePreviewService?
    private(set) var readReceipts: ReadReceiptService?
    private(set) var recipientBar: RecipientBarService?
    private(set) var recordingUI: RecordingUIService?
    private(set) var searchInteraction: SearchInteractionService?
    private(set) var tapGestureRecognizer: TapGestureRecognizerService?
    private(set) var typingIndicator: TypingIndicatorService?

    private var configuration: ChatPageView.Configuration = .default
    private var viewController: ChatPageViewController?

    // MARK: - Computed Properties

    private var shouldRespondToViewLifecycleEvent: Bool {
        guard !chatInfoPageViewService.isPreviewingMedia,
              mediaActionHandler?.isPresentingPickerController != true,
              mediaMessagePreview?.isPreviewingMedia != true else { return false }

        return true
    }

    // MARK: - Instantiate View Controller

    func instantiateViewController(
        _ conversation: Conversation,
        configuration: ChatPageView.Configuration
    ) -> MessagesViewController {
        clientSession.conversation.resetMessageOffset()
        clientSession.conversation.setCurrentConversation(conversation)

        if let focusedMessageID = configuration.focusedMessageID {
            clientSession.conversation.incrementMessageOffset(to: focusedMessageID)
        }

        // NIT: Could store [ConversationID: ViewController] and allow for multiple presentations (i.e., "Add Contact" button) that way?

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
        readReceipts = .init(viewController)
        recordingUI = .init(viewController)
        searchInteraction = .init(viewController, focusedMessageID: configuration.focusedMessageID)
        tapGestureRecognizer = .init(viewController)
        typingIndicator = .init(viewController)

        viewController.scrollsToLastItemOnKeyboardBeginsEditing = configuration.focusedMessageID == nil
        guard configuration == .newChat else { return viewController }

        let recipientBarService = RecipientBarService(viewController)
        recipientBar = recipientBarService
        chatPageViewControllerFactory.configureRecipientBar(viewController, service: recipientBarService)

        return viewController
    }

    // MARK: - View Controller Lifecycle Handlers

    func onViewWillAppear() {
        guard shouldRespondToViewLifecycleEvent else { return }

        Message.consentRequestMessageID = nil
        viewController?.view.isUserInteractionEnabled = false

        modifyConfigurationIfNeeded()
        chatPageState.setIsPresented(true)
        updateCollectionViewBackgroundColor()

        if configuration == .newChat {
            viewController?.messageInputBar.inputTextView.placeholder = ""
        }

        viewController?.messageInputBar.alpha = configuration == .default ? 0 : 1

        guard configuration == .default else { return }
        NavigationBar.setAppearance(.chatPageView)
        startSettingNavigationBarButtonItemAppearance()
    }

    func onViewDidAppear() {
        guard shouldRespondToViewLifecycleEvent else { return }
        typingIndicator?.startCheckingForTypingIndicatorChanges()
        InteractivePopGestureRecognizer.setIsEnabled(true)

        guard configuration != .preview else {
            viewController?.messageInputBar.isHidden = true
            Task.delayed(by: .milliseconds(Floats.scrollDelayMilliseconds)) { @MainActor [weak self] in
                if let focusedMessageID = self?.configuration.focusedMessageID {
                    self?.viewController?.messagesCollectionView.scrollTo(
                        messageID: focusedMessageID,
                        at: .centeredVertically,
                        animated: false
                    )
                } else {
                    self?.viewController?.messagesCollectionView.scrollToLastItem(animated: false)
                }
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
            if let focusedMessageID = configuration.focusedMessageID {
                viewController?.messagesCollectionView.scrollTo(messageID: focusedMessageID)
            } else {
                viewController?.messagesCollectionView.scrollToLastItem()
            }

            UIView.animate(
                withDuration: Floats.inputBarAppearanceAnimationDuration,
                delay: Floats.inputBarAppearanceAnimationDuration
            ) { [weak self] in
                self?.viewController?.messageInputBar.alpha = 1
            }
        }

        services.connectionStatus.addEffectUponConnectionChanged(id: .configureInputBar) { [weak self] in
            self?.inputBar?.configureInputBar(forceUpdate: true)
        }

        if let readReceipts {
            Task { @MainActor in
                if let exception = await readReceipts.updateReadDateForUnreadMessages() {
                    Logger.log(exception, with: .toastInPrerelease)
                }

                if let exception = await typingIndicator?.textViewDidChange(to: "") {
                    Logger.log(exception, with: .toastInPrerelease)
                }
            }
        }

        viewController?.becomeFirstResponder()
        viewController?.view.isUserInteractionEnabled = true

        Task.delayed(by: .milliseconds(
            Floats.triggerFocusedMessageCellInteractionDelayMilliseconds
        )) { @MainActor in
            searchInteraction?.triggerFocusedMessageCellInteractionIfNeeded()
        }
    }

    func onViewWillDisappear() {
        guard shouldRespondToViewLifecycleEvent else { return }

        Message.consentRequestMessageID = nil
        NavigationBar.setAppearance(.conversationsPageView)
        contextMenu?.interaction.stopAddingContextMenuInteractionToVisibleCells()
        typingIndicator?.stopCheckingForTypingIndicatorChanges()
    }

    func onViewDidDisappear() {
        guard shouldRespondToViewLifecycleEvent else { return }

        chatPageState.setIsPresented(false)
        contextMenu?.interaction.removeKeyboardWillShowObserver()

        Task.background { @MainActor in
            if let exception = await typingIndicator?.textViewDidChange(to: "") {
                Logger.log(exception)
            }

            // TODO: Audit this.
            // clientSession.conversation.setCurrentConversation(nil)
            clientSession.conversation.resetMessageOffset()
        }

        alternateMessage?.restoreAllAlternateTextMessageIDs()
        alternateMessage?.restoreAllAudioTranscriptionMessageIDs()

        ConversationsPageView.reapplyNavigationBarItemGlassTintIfNeeded()
        services.connectionStatus.removeEffect(.configureInputBar)

        avSpeechSynthesizer.stopSpeaking(at: .immediate)
        audioMessagePlayback?.stopPlayback()
        if let exception = services.audio.recording.cancelRecording() {
            guard !exception.isEqual(to: .noAudioRecorderToStop) else { return }
            Logger.log(exception, with: .toastInPrerelease)
        }
    }

    // MARK: - UIScrollView

    func onScrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.panGestureRecognizer.translation(in: scrollView.superview).y > 0 else { return }
        loadMoreMessages(fromScrollToTop: false)
    }

    func onScrollViewDidEndScrollingAnimation() {
        searchInteraction?.triggerFocusedMessageCellInteractionIfNeeded()
    }

    func onScrollViewDidScrollToTop() {
        loadMoreMessages(fromScrollToTop: true)
    }

    // MARK: - UITraitCollection

    func onTraitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard previousTraitCollection?.userInterfaceStyle != viewController?.traitCollection.userInterfaceStyle else { return }
        redrawForAppearanceChange()
    }

    // MARK: - Auxiliary

    func redrawForAppearanceChange() {
        inputBar?.configureInputBar(forceUpdate: true)
        inputBar?.setAttachMediaButtonImage()
        recipientBar?.layout.layoutSubviews()
        recipientBar?.contactSelectionUI.unhighlightAllViews()

        if configuration == .newChat {
            NavigationBar.setAppearance(.newChatPageView)
        } else if !uiApplication.isPresentingSheet {
            NavigationBar.setAppearance(.chatPageView)
        }

        StatusBar.overrideStyle(.appAware)
        UIView.dismissCurrentContextMenu()
        viewController?.navigationController?.isNavigationBarHidden = true
        viewController?.navigationController?.isNavigationBarHidden = false
        updateCollectionViewBackgroundColor()
        reloadCollectionView()
    }

    func reloadCollectionView() {
        guard viewController?.currentConversation?.messages?.count == 1 else {
            viewController?.messagesCollectionView.reloadDataAndKeepOffset()
            return
        }

        viewController?.messagesCollectionView.reloadData()
    }

    func reloadItemsWhenSafe(
        at indexPaths: [IndexPath],
        animated isAnimated: Bool = true
    ) {
        if clientSession.reaction.isReactingToMessage {
            clientSession.reaction.addEffectUponIsReactingToMessage(
                changedTo: false,
                id: .reloadCollectionView
            ) { [weak self] in
                self?.reloadItemsWhenSafe(
                    at: indexPaths,
                    animated: isAnimated
                )
            }
        } else if messageDeliveryService.isSendingMessage {
            messageDeliveryService.addEffectUponIsSendingMessage(
                changedTo: false,
                id: .reloadCollectionView
            ) { [weak self] in
                self?.reloadItemsWhenSafe(
                    at: indexPaths,
                    animated: isAnimated
                )
            }
        } else {
            safelyReload(
                indexPaths: indexPaths,
                conversationIDKey: clientSession
                    .conversation
                    .currentConversation?
                    .id
                    .key,
                structure: viewController == nil ? nil : (0 ..< viewController!.messagesCollectionView.numberOfSections).map {
                    viewController!.messagesCollectionView.numberOfItems(inSection: $0)
                },
                animated: isAnimated
            )
        }
    }

    func setNavigationTitle(_ navigationTitle: String) {
        guard let parent = viewController?.parent else { return }
        parent.navigationItem.title = navigationTitle
    }

    private func loadMoreMessages(fromScrollToTop: Bool) {
        guard !messageDeliveryService.isSendingMessage else { return }

        let previousMessageCount = clientSession.conversation.currentConversation?.messages?.count
        clientSession.conversation.incrementMessageOffset()
        guard previousMessageCount != clientSession.conversation.currentConversation?.messages?.count else { return }
        reloadCollectionView()

        guard fromScrollToTop else { return }
        Task.delayed(by: .milliseconds(Floats.loadMoreMessagesDelayMilliseconds)) { @MainActor [weak self] in
            guard let viewController = self?.viewController,
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
        guard presentedViewControllerIDs.contains(Strings.chatPageViewPreviewHostingControllerID),
              configuration != .preview else { return }

        Logger.log(
            "Intercepted misconfigured preview bug.",
            domain: .bugPrevention,
            sender: self
        )

        configuration = .preview
    }

    private func safelyReload(
        indexPaths: [IndexPath],
        conversationIDKey previousConversationIDKey: String?,
        structure previousStructure: [Int]?,
        animated isAnimated: Bool
    ) {
        guard let previousConversationIDKey,
              let previousStructure else { return }

        func reloadItem(
            collectionView: MessagesCollectionView,
            viewController: ChatPageViewController
        ) {
            let currentStructure = (0 ..< collectionView.numberOfSections).map {
                collectionView.numberOfItems(inSection: $0)
            }

            guard currentStructure == previousStructure,
                  chatPageState.isPresented,
                  previousConversationIDKey == clientSession
                  .conversation
                  .currentConversation?
                  .id
                  .key else { return }

            let validIndexPaths = indexPaths.filter {
                !viewController.isSectionReservedForTypingIndicator($0.section) &&
                    $0.section >= 0 &&
                    $0.section < collectionView.numberOfSections &&
                    $0.item >= 0 &&
                    $0.item < collectionView.numberOfItems(inSection: $0.section)
            }

            guard !validIndexPaths.isEmpty else { return }
            collectionView.reloadItems(at: validIndexPaths)
        }

        guard isAnimated else {
            guard let viewController else { return }
            return reloadItem(
                collectionView: viewController.messagesCollectionView,
                viewController: viewController
            )
        }

        let collectionView = viewController?.messagesCollectionView
        collectionView?
            .performBatchUpdates(nil) { [weak self, weak collectionView] _ in
                guard let collectionView,
                      let viewController = self?.viewController else { return }

                reloadItem(
                    collectionView: collectionView,
                    viewController: viewController
                )
            }
    }

    private func startSettingNavigationBarButtonItemAppearance() {
        guard !UIApplication.isFullyV26Compatible,
              chatPageState.isPresented else { return }
        guard let leafViewController = uiApplication.keyViewController?.leafViewController,
              leafViewController.descriptor == Strings.leafViewControllerID else {
            Task.delayed(by: .seconds(1)) { @MainActor [weak self] in
                self?.startSettingNavigationBarButtonItemAppearance()
            }
            return
        }

        let misconfiguredBarButtonItemViews: [UIButton] = uiApplication
            .presentedViews
            .compactMap { $0 as? UIButton }
            .filter { String(type(of: $0.self)) == Strings.barButtonItemViewID }
            .filter { $0.tintColor != (Application.isInPrevaricationMode ? .navigationBarTitle : .accent) }

        misconfiguredBarButtonItemViews.forEach { $0.tintColor = Application.isInPrevaricationMode ? .navigationBarTitle : .accent }
        Task.delayed(by: .milliseconds(Floats.setNavigationBarButtonItemAppearanceDelayMilliseconds)) { @MainActor in
            startSettingNavigationBarButtonItemAppearance()
        }
    }

    private func updateCollectionViewBackgroundColor() {
        guard !Application.isInPrevaricationMode else { return }
        var backgroundColor = ThemeService.isAppDefaultThemeApplied ? UIColor.background : UIColor(Colors.messagesCollectionViewPrimaryDarkBackground)
        if configuration != .default,
           ThemeService.isDarkModeActive {
            backgroundColor = UIColor(Colors.messagesCollectionViewSecondaryDarkBackground)
        }

        viewController?.messagesCollectionView.backgroundColor = backgroundColor
        viewController?.messagesCollectionView.backgroundView?.backgroundColor = backgroundColor
        viewController?.view.backgroundColor = backgroundColor
    }
}

// swiftlint:enable file_length type_body_length
