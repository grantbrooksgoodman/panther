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

    private enum TaskID: Hashable {
        case showSecondsToLoadToast
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.conversationsPageViewService) private var conversationsPageViewService: ConversationsPageViewService
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.traitCollectionChanged,
        Observables.updateConversationsListSetToReliableDataSource,
        Observables.updatedContactPairArchive,
        Observables.updatedCurrentUser,
    ]

    let viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.traitCollectionChanged,
             Observables.updatedContactPairArchive:
            send(.traitCollectionChanged)

        case Observables.updateConversationsListSetToReliableDataSource:
            Task.debounced(
                TaskID.showSecondsToLoadToast,
                delay: .seconds(1),
            ) { @MainActor in
                conversationsPageViewService.showSecondsToLoadToastIfNeeded()
            }

        case Observables.updatedCurrentUser:
            Task { @MainActor in
                guard chatPageState.isPresented else { return updateConversations() }

                chatPageState.addEffectUponIsPresented(
                    changedTo: false,
                    id: .updateCurrentUser
                ) { send(.updatedCurrentUser) }

                // The signal may have already fired before this Task ran.
                // If it did, call updateConversations() directly rather than
                // waiting for a transition that already happened.
                guard !chatPageState.isWaitingToUpdateConversations else { return updateConversations() }

                chatPageState.addEffectUponIsWaitingToUpdateConversations(
                    changedTo: true,
                    id: .updateConversations
                ) { updateConversations() }
            }

        default: ()
        }
    }

    // MARK: - Auxiliary

    @MainActor
    private func updateConversations() {
        guard !chatPageState.isPresented || !messageDeliveryService.isSendingMessage else {
            Logger.log(
                "Awaiting message send completion before updating conversations...",
                domain: .conversation,
                sender: self
            )

            return messageDeliveryService.addEffectUponIsSendingMessage(
                changedTo: false,
                id: .updateConversations
            ) { _updateConversations() }
        }

        _updateConversations()
    }

    private func _updateConversations() {
        Task { @MainActor in
            networking.database.setGlobalCacheStrategy(.returnCacheOnFailure)
            networking.storage.setGlobalCacheStrategy(.returnCacheOnFailure)

            if let exception = await clientSession
                .user
                .currentUser?
                .conversations?
                .visibleForCurrentUser
                .setUsers() {
                Logger.log(
                    exception,
                    domain: .conversation,
                    with: .toastInPrerelease
                )
            }

            defer {
                networking.database.setGlobalCacheStrategy(nil)
                networking.storage.setGlobalCacheStrategy(nil)
            }

            guard chatPageState.isPresented else { return send(.updatedCurrentUser) }
            defer { chatPageState.setIsWaitingToUpdateConversations(false) }

            guard let currentConversation = clientSession.conversation.fullConversation,
                  let updatedConversation = clientSession
                  .user
                  .currentUser?
                  .conversations?
                  .first(where: { $0.id.key == currentConversation.id.key }) else { return }

            let currentMessageIDs = Set(
                currentConversation.messages?.filteringSystemMessages.map(\.id) ?? []
            )

            if let missingMessages = updatedConversation.messages?
                .filteringSystemMessages
                .filter({
                    !currentMessageIDs.contains($0.id) &&
                        !$0.isFromCurrentUser &&
                        $0.currentUserReadReceipt == nil
                }),
                !missingMessages.isEmpty {
                let updateReadDateResult = await updatedConversation.updateReadDate(
                    for: missingMessages
                )

                switch updateReadDateResult {
                case let .success(conversation):
                    if let badgeNumber = await clientSession.user.currentUser?.calculateBadgeNumber(),
                       let exception = await notificationService.setBadgeNumber(badgeNumber) {
                        Logger.log(
                            exception,
                            domain: .conversation
                        )
                    }

                    guard matchesCurrentConversation(conversation.id.key) else { return }
                    clientSession.conversation.setCurrentConversation(conversation)
                    chatPageViewService.reloadCollectionView()
                    return configureInputBarIfNeeded()

                case let .failure(exception):
                    return Logger.log(
                        exception,
                        domain: .conversation
                    )
                }
            }

            guard matchesCurrentConversation(updatedConversation.id.key) else { return }

            // If a user was added/removed, resolve the users again.
            if currentConversation.participants.count != updatedConversation.participants.count,
               let exception = await updatedConversation.setUsers(forceUpdate: true) {
                Logger.log(
                    exception,
                    domain: .conversation,
                    with: .toastInPrerelease
                )
            }

            clientSession.conversation.setCurrentConversation(updatedConversation)
            chatPageState.setIsWaitingToUpdateConversations(false) // Allow typing indicator to appear.

            if chatPageViewService.recipientBar?.layout.recipientBarView == nil,
               let navigationTitle = ConversationCellViewData(
                   updatedConversation,
                   useCachedValue: currentConversation.participants.count == updatedConversation.participants.count
               )?.titleLabelText {
                chatPageViewService.setNavigationTitle(navigationTitle)
            }

            guard currentConversation.id.hash != updatedConversation.id.hash else { return }
            chatPageViewService.reloadCollectionView() // Reload to display updated read date / reactions.
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
        clientSession.conversation.currentConversation?.id.key == idKey
    }
}
