//
//  ConversationsPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

struct ConversationsPageObserver: Observer {
    // MARK: - Type Aliases

    typealias R = ConversationsPageReducer

    // MARK: - Types

    private enum TaskID: String {
        case handleChatPageStoreChange
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.sessionStoreDidChange,
        Observables.traitCollectionChanged,
        Observables.updatedContactPairArchive,
    ]

    let viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.sessionStoreDidChange:
            send(.sessionStoreDidChange)
            Task.debounced(
                "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.handleChatPageStoreChange.rawValue)",
                delay: .milliseconds(250),
                priority: .userInitiated
            ) { @MainActor [self] in
                handleChatPageStoreChange()
            }

        case Observables.traitCollectionChanged,
             Observables.updatedContactPairArchive:
            send(.traitCollectionChanged)

        default: ()
        }
    }

    // MARK: - Auxiliary

    /// Handles chat-page–specific behaviors (read receipts, badge number,
    /// 1:1 read-receipt re-fetch, navigation title, consent button) in
    /// response to debounced store changes.
    @MainActor
    private func handleChatPageStoreChange() {
        guard chatPageState.isPresented else { return }

        guard !messageDeliveryService.isSendingMessage else {
            Logger.log(
                "Awaiting message send completion before handling chat page store change...",
                domain: .conversation,
                sender: self
            )

            return messageDeliveryService.addEffectUponIsSendingMessage(
                changedTo: false,
                id: .updateConversations
            ) { handleChatPageStoreChange() }
        }

        // swiftlint:disable:next closure_body_length
        Task { @MainActor in
            guard let currentConversation = entitySession
                .conversation
                .currentConversation else { return }

            // Re-fetch the last message in 1:1 conversations to pick up
            // read receipt changes that don't affect the conversation hash.
            if currentConversation.participants.count == 2,
               let lastMessageID = currentConversation.messages?.last?.id ?? currentConversation.messageIDs.last {
                do {
                    try await networking.database.withGlobalCacheStrategy(
                        .returnCacheOnFailure
                    ) {
                        try await currentConversation.resolveMessages(
                            ids: [lastMessageID]
                        )
                    }
                } catch {
                    Logger.log(
                        .init(
                            error,
                            metadata: .init(sender: self)
                        ),
                        domain: .conversation
                    )
                }
            }

            // Mark unread messages as read and update the badge.
            if let unreadMessages = currentConversation.messages?
                .filter({
                    !$0.isFromCurrentUser &&
                        $0.currentUserReadReceipt == nil
                }),
                !unreadMessages.isEmpty {
                do throws(Exception) {
                    try await currentConversation.updateReadDate(
                        for: unreadMessages
                    )

                    if let badgeNumber = entitySession
                        .user
                        .currentUser?
                        .calculateBadgeNumber() {
                        do throws(Exception) {
                            try await notificationService.setBadgeNumber(
                                badgeNumber
                            )
                        } catch {
                            Logger.log(
                                error,
                                domain: .conversation
                            )
                        }
                    }

                    guard matchesCurrentConversation(currentConversation.id.key) else { return }
                    return configureInputBarIfNeeded()
                } catch {
                    return Logger.log(
                        error,
                        domain: .conversation
                    )
                }
            }

            guard matchesCurrentConversation(currentConversation.id.key) else { return }

            if chatPageViewService.recipientBar?.layout.recipientBarView == nil,
               let navigationTitle = ConversationCellViewData(
                   currentConversation,
                   useCachedValue: true
               )?.titleLabelText {
                chatPageViewService.setNavigationTitle(navigationTitle)
            }

            configureInputBarIfNeeded()
            Observables.currentConversationMetadataChanged.trigger()
        }
    }

    @MainActor
    private func configureInputBarIfNeeded() {
        guard chatPageViewService.inputBar?.isShowingConsentButton == true else { return }
        chatPageViewService.inputBar?.configureInputBar()
    }

    private func matchesCurrentConversation(_ idKey: String) -> Bool {
        entitySession.conversation.currentConversation?.id.key == idKey
    }
}
