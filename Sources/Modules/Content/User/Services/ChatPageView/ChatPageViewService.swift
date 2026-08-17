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

/// The service that orchestrates the chat page.
///
/// ``ChatPageViewService`` connects the chat page's messages view controller to the app's
/// services. It creates the view controller through ``ChatPageViewControllerFactory``, wires a
/// family of sub-services to it – the input bar, context menus, read receipts, media handling,
/// and more – and responds to the view controller's lifecycle, scroll, and trait events.
///
/// The chat page presents in one of three configurations:
///
/// - The default configuration displays an existing conversation.
/// - The new chat configuration adds a recipient bar for choosing whom to message.
/// - The preview configuration displays a read-only preview with the input bar hidden.
///
/// While the page is visible, the service observes session store and message outbox changes,
/// reloading the message list whenever the displayed conversation's data changes.
///
/// - Important: The service ignores lifecycle events that occur while a media preview or picker
///   is presented over the page; those events reflect the page being covered and uncovered, not
///   presented and dismissed.
///
/// - Note: The sub-service properties are `nil` until
///   ``instantiateViewController(_:configuration:)`` first runs; each call replaces them with
///   instances bound to the new view controller.
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

    /// The service that manages messages displaying alternate content, such as original text or
    /// audio transcriptions.
    private(set) var alternateMessage: AlternateMessageService?

    /// The service that manages audio message playback.
    private(set) var audioMessagePlayback: AudioMessagePlaybackService?

    /// The service that manages message context menus.
    private(set) var contextMenu: ContextMenuService?

    /// The service that manages the message delivery progress bar.
    private(set) var deliveryProgressIndicator: DeliveryProgressIndicatorService?

    /// The service that manages the message input bar.
    private(set) var inputBar: InputBarService?

    /// The service that manages the input bar's gesture recognizers.
    private(set) var inputBarGestureRecognizer: InputBarGestureRecognizerService?

    /// The service that handles media attachment actions.
    private(set) var mediaActionHandler: MediaActionHandlerService?

    /// The service that manages media message previews.
    private(set) var mediaMessagePreview: MediaMessagePreviewService?

    /// The service that manages read receipts.
    private(set) var readReceipts: ReadReceiptService?

    /// The service that manages the recipient bar. Created only for the new chat configuration.
    private(set) var recipientBar: RecipientBarService?

    /// The service that manages the audio recording interface.
    private(set) var recordingUI: RecordingUIService?

    /// The service that manages focusing a message from search.
    private(set) var searchInteraction: SearchInteractionService?

    /// The service that manages the page's tap gesture recognizer.
    private(set) var tapGestureRecognizer: TapGestureRecognizerService?

    /// The service that manages the typing indicator.
    private(set) var typingIndicator: TypingIndicatorService?

    private var configuration: ChatPageView.Configuration = .default
    @SharedEvent(\.messageOutboxDidChange) private var messageOutboxDidChange
    private var outboxChangeTask: Task<Void, Never>?
    private var sessionStoreChangeTask: Task<Void, Never>?
    @SharedEvent(\.sessionStoreDidChange) private var sessionStoreDidChange
    private var viewController: ChatPageViewController?

    // MARK: - Computed Properties

    private var shouldRespondToViewLifecycleEvent: Bool {
        guard !chatInfoPageViewService.isPreviewingMedia,
              mediaActionHandler?.isPresentingPickerController != true,
              mediaMessagePreview?.isPreviewingMedia != true else { return false }

        return true
    }

    // MARK: - Instantiate View Controller

    /// Creates and configures the messages view controller for the given conversation.
    ///
    /// This method makes the given conversation current, resets the conversation's message
    /// offset – advancing it to the focused message when the configuration specifies one – and
    /// builds a new view controller through ``ChatPageViewControllerFactory``. It then creates
    /// the sub-services for the new presentation, binding each to the view controller. For the
    /// new chat configuration, it also creates and installs the recipient bar.
    ///
    /// - Parameters:
    ///   - conversation: The conversation to display.
    ///   - configuration: The configuration to present the page in.
    ///
    /// - Returns: The configured messages view controller.
    func instantiateViewController(
        _ conversation: Conversation,
        configuration: ChatPageView.Configuration
    ) -> MessagesViewController {
        clientSession.entity.conversation.resetMessageOffset()
        clientSession.entity.conversation.setCurrentConversation(conversation)

        if let focusedMessageID = configuration.focusedMessageID {
            clientSession.entity.conversation.incrementMessageOffset(to: focusedMessageID)
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

    /// Prepares the page as it begins to appear.
    ///
    /// This method disables user interaction until ``onViewDidAppear()`` completes, marks the
    /// chat page presented, and applies the appropriate background and navigation bar
    /// appearances. In the default configuration, it hides the input bar so it can fade in once
    /// the page has appeared.
    ///
    /// - Note: This method has no effect while a media preview or picker is presented over the
    ///   page.
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

    /// Completes the page's appearance.
    ///
    /// In the preview configuration, this method hides the input bar and scrolls to the focused
    /// message – or to the latest message – without further setup. Otherwise, it:
    ///
    /// - Starts observing the displayed conversation when it is stored, skipping drafts and
    ///   mocks.
    /// - Begins observing session store and message outbox changes for the duration of the
    ///   presentation.
    /// - Configures the page's gesture recognizers, context menu interactions, and input bar,
    ///   reconfiguring the input bar whenever the connection status changes.
    /// - In the default configuration, logs an analytics event, scrolls to the focused or latest
    ///   message, and fades the input bar in.
    /// - Updates read dates for unread messages and clears the user's typing indicator status.
    /// - Restores user interaction.
    ///
    /// - Note: This method has no effect while a media preview or picker is presented over the
    ///   page.
    func onViewDidAppear() {
        guard shouldRespondToViewLifecycleEvent else { return }
        InteractivePopGestureRecognizer.setIsEnabled(true)

        guard configuration != .preview else {
            viewController?.messageInputBar.isHidden = true
            Task.delayed(
                by: .milliseconds(Floats.scrollDelayMilliseconds)
            ) { @MainActor [weak self] in
                guard let collectionView = self?.viewController?.messagesCollectionView else { return }

                collectionView.contentInset.bottom = Floats.previewConfigBottomInset
                collectionView.verticalScrollIndicatorInsets.bottom = Floats.previewConfigBottomInset

                if let focusedMessageID = self?.configuration.focusedMessageID {
                    collectionView.scrollTo(
                        messageID: focusedMessageID,
                        at: .centeredVertically,
                        animated: false
                    )
                } else {
                    collectionView.scrollToLastItem(animated: false)
                }
            }
            return
        }

        // Start observer for stored conversations
        // (skips drafts and mocks).
        if let currentConversation = clientSession.entity.conversation.currentConversation,
           !currentConversation.isEmpty,
           !currentConversation.isMock {
            clientSession.sync.conversationObserver.startObserving(
                conversationIDKey: currentConversation.id.key
            )
        }

        if outboxChangeTask == nil {
            outboxChangeTask = Task { [weak self] in
                guard let outboxChanges = self?.messageOutboxDidChange.events else { return }
                for await _ in outboxChanges {
                    self?.handleOutboxChange()
                }
            }
        }

        if sessionStoreChangeTask == nil {
            sessionStoreChangeTask = Task { [weak self] in
                guard let sessionStoreChanges = self?.sessionStoreDidChange.events else { return }
                for await change in sessionStoreChanges {
                    guard [.conversations, .messages].contains(change.kind) else { continue }
                    self?.handleSessionStoreChange(change)
                }
            }
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

        Task { @MainActor in
            do throws(Exception) {
                try await readReceipts?.updateReadDateForUnreadMessages()
                try await typingIndicator?.textViewDidChange(to: "")
            } catch {
                Logger.log(error)
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

    /// Prepares the page as it begins to disappear.
    ///
    /// This method restores the conversations page's navigation bar appearance and stops adding
    /// context menu interactions to message cells.
    ///
    /// - Note: This method has no effect while a media preview or picker is presented over the
    ///   page.
    func onViewWillDisappear() {
        guard shouldRespondToViewLifecycleEvent else { return }

        Message.consentRequestMessageID = nil
        NavigationBar.setAppearance(.conversationsPageView)
        contextMenu?.interaction.stopAddingContextMenuInteractionToVisibleCells()
    }

    /// Completes the page's disappearance.
    ///
    /// This method marks the chat page dismissed, stops conversation, session store, and outbox
    /// observation, clears the user's typing indicator status, restores any messages displaying
    /// alternate content, and stops speech synthesis, audio playback, and any in-progress
    /// recording.
    ///
    /// The current conversation pointer is cleared only when the page is truly being dismissed –
    /// not when it is covered by a sheet or preview.
    ///
    /// - Note: This method has no effect while a media preview or picker is presented over the
    ///   page.
    func onViewDidDisappear() {
        guard shouldRespondToViewLifecycleEvent else { return }

        chatPageState.setIsPresented(false)
        clientSession.sync.conversationObserver.stopObserving()

        outboxChangeTask?.cancel()
        outboxChangeTask = nil

        sessionStoreChangeTask?.cancel()
        sessionStoreChangeTask = nil

        contextMenu?.interaction.removeKeyboardWillShowObserver()

        Task.background { @MainActor [weak self] in
            guard let self else { return }

            do throws(Exception) {
                try await typingIndicator?.textViewDidChange(to: "")
            } catch {
                Logger.log(error)
            }

            // Clear the pointer only when the page is truly
            // being dismissed – not when covered by a sheet
            // or preview.
            if !chatPageState.isPresented,
               configuration != .preview {
                // Flush any read receipts still pending from a session store
                // change that arrived within the debounce window before the
                // page was popped, which would otherwise be dropped when
                // `handleChatPageStoreChange` bails on the cleared pointer.
                do throws(Exception) {
                    try await readReceipts?.updateReadDateForUnreadMessages()
                } catch {
                    Logger.log(error)
                }

                clientSession.entity.conversation.setCurrentConversation(nil)
            }

            clientSession.entity.conversation.resetMessageOffset()
        }

        alternateMessage?.restoreAllAlternateTextMessageIDs()
        alternateMessage?.restoreAllAudioTranscriptionMessageIDs()

        ConversationsPageView.reapplyNavigationBarItemGlassTintIfNeeded()
        services.connectionStatus.removeEffect(.configureInputBar)

        avSpeechSynthesizer.stopSpeakingIfNeeded()
        audioMessagePlayback?.stopPlayback()

        do {
            try services.audio.recording.cancelRecording()
        } catch {
            guard !error.isEqual(to: .noAudioRecorderToStop) else { return }
            Logger.log(
                error,
                with: .toastInPrerelease
            )
        }
    }

    // MARK: - UIScrollView

    /// Tells the service that the scroll view stopped decelerating.
    ///
    /// When the user was scrolling toward the top of the conversation, this method loads older
    /// messages into the message list.
    ///
    /// - Parameter scrollView: The scroll view that stopped decelerating.
    func onScrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.panGestureRecognizer.translation(in: scrollView.superview).y > 0 else { return }
        loadMoreMessages(fromScrollToTop: false)
    }

    /// Tells the service that a scrolling animation finished. Triggers the focused message's
    /// cell interaction when one is pending.
    func onScrollViewDidEndScrollingAnimation() {
        searchInteraction?.triggerFocusedMessageCellInteractionIfNeeded()
    }

    /// Tells the service that the scroll view scrolled to the top. Loads older messages into the
    /// message list, then scrolls to the topmost message.
    func onScrollViewDidScrollToTop() {
        loadMoreMessages(fromScrollToTop: true)
    }

    // MARK: - UITraitCollection

    /// Tells the service that the view controller's trait collection changed. Redraws the page
    /// when the user interface style changed.
    ///
    /// - Parameter previousTraitCollection: The trait collection before the change.
    func onTraitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard previousTraitCollection?.userInterfaceStyle != viewController?.traitCollection.userInterfaceStyle else { return }
        redrawForAppearanceChange()
    }

    // MARK: - Auxiliary

    /// Redraws the page for an appearance change, such as a switch between light and dark mode.
    ///
    /// This method reconfigures the input bar, lays out the recipient bar, reapplies the
    /// navigation and status bar appearances, dismisses any presented context menu, and reloads
    /// the message list with the updated background color.
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

        if !UIApplication.isFullyV26Compatible {
            viewController?.navigationController?.isNavigationBarHidden = true
            viewController?.navigationController?.isNavigationBarHidden = false
        }

        updateCollectionViewBackgroundColor()
        reloadCollectionView()
    }

    /// Reloads the message list.
    ///
    /// Unless exactly one message is displayed, the reload preserves the current scroll offset.
    func reloadCollectionView() {
        guard viewController?.displayedMessages.count == 1 else {
            viewController?.messagesCollectionView.reloadDataAndKeepOffset()
            return
        }

        viewController?.messagesCollectionView.reloadData()
    }

    /// Reloads the items at the given index paths once it is safe to do so.
    ///
    /// If a message reaction or send is in progress, the reload is deferred until the operation
    /// completes. Before reloading, the method validates that the chat page is still presented,
    /// that the displayed conversation has not changed, and that the message list's structure
    /// still matches its structure at the time of the call; if any check fails, the reload is
    /// skipped.
    ///
    /// - Parameters:
    ///   - indexPaths: The index paths of the items to reload.
    ///   - isAnimated: A Boolean value that indicates whether the reload is animated.
    func reloadItemsWhenSafe(
        at indexPaths: [IndexPath],
        animated isAnimated: Bool = true
    ) {
        if clientSession.entity.reaction.isReactingToMessage {
            clientSession.entity.reaction.addEffectUponIsReactingToMessage(
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
                    .entity
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

    /// Sets the navigation title of the page's parent view controller.
    ///
    /// This method has no effect when the view controller has no parent.
    ///
    /// - Parameter navigationTitle: The title to display.
    func setNavigationTitle(_ navigationTitle: String) {
        guard let parent = viewController?.parent else { return }
        parent.navigationItem.title = navigationTitle
    }

    private func loadMoreMessages(fromScrollToTop: Bool) {
        guard !messageDeliveryService.isSendingMessage else { return }

        let previousMessageCount = clientSession.entity.conversation.displayedMessages.count
        clientSession.entity.conversation.incrementMessageOffset()
        guard previousMessageCount != clientSession.entity.conversation.displayedMessages.count else { return }
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
                  .entity
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
