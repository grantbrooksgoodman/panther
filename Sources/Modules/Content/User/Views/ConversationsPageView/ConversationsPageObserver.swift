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
        case showSecondsToLoadToast
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService
    @Dependency(\.conversationsPageViewService) private var viewService: ConversationsPageViewService

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.sessionStoreDidChange,
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
        case Observables.sessionStoreDidChange:
            send(.sessionStoreDidChange)

        case Observables.traitCollectionChanged,
             Observables.updatedContactPairArchive:
            send(.traitCollectionChanged)

        case Observables.updateConversationsListSetToReliableDataSource:
            @MainActorIsolated var didShowSecondsToLoadToast = viewService.didShowSecondsToLoadToast
            guard !didShowSecondsToLoadToast else { return }
            Task.debounced(
                "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.showSecondsToLoadToast.rawValue)",
                delay: .seconds(1)
            ) { @MainActor in
                viewService.showSecondsToLoadToastIfNeeded()
            }

        case Observables.updatedCurrentUser:
            Task { @MainActor in
                guard chatPageState.isPresented else {
                    // If a message is still mid-send (e.g. the user dismissed the
                    // chat page before delivery completed), enqueue an update so
                    // the conversations list refreshes once delivery finishes.
                    if messageDeliveryService.isSendingMessage {
                        messageDeliveryService.addEffectUponIsSendingMessage(
                            changedTo: false,
                            id: .updateConversations
                        ) { updateConversations() }
                    }

                    return updateConversations()
                }

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

    // swiftlint:disable:next function_body_length
    private func _updateConversations() {
        Task { @MainActor in
            let previousConversationHash = clientSession.conversation.baselineConversationHash
            let previousMessageIDs = clientSession.conversation.baselineMessageIDs
            let previousParticipantCount = clientSession.conversation.baselineParticipantCount

            networking.database.setGlobalCacheStrategy(.returnCacheOnFailure)
            networking.storage.setGlobalCacheStrategy(.returnCacheOnFailure)

            do throws(Exception) {
                try await clientSession.user.resolveCurrentUser(
                    and: [
                        .messages,
                        .users,
                    ]
                )
            } catch {
                Logger.log(
                    error,
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

            guard let currentConversation = clientSession.conversation.currentConversation,
                  let updatedConversation = clientSession
                  .user
                  .currentUser?
                  .conversations?
                  .first(where: { $0.id.key == currentConversation.id.key }) else { return }

            // Re-fetch the last message in 1:1 conversations to pick up
            // read receipt changes that don't affect the conversation hash.
            if currentConversation.participants.count == 2,
               let lastMessageID = currentConversation.messages?.last?.id ?? currentConversation.messageIDs.last {
                do throws(Exception) {
                    try await currentConversation.resolveMessages(
                        ids: [lastMessageID]
                    )
                } catch {
                    Logger.log(
                        error,
                        domain: .conversation
                    )
                }
            }

            if let missingMessages = updatedConversation.messages?
                .filter({
                    !previousMessageIDs.contains($0.id) &&
                        !$0.isFromCurrentUser &&
                        $0.currentUserReadReceipt == nil
                }),
                !missingMessages.isEmpty {
                do throws(Exception) {
                    try await updatedConversation.updateReadDate(
                        for: missingMessages
                    )

                    if let badgeNumber = clientSession
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

                    guard matchesCurrentConversation(updatedConversation.id.key) else { return }
                    clientSession.conversation.setCurrentConversation(updatedConversation)
                    chatPageViewService.reloadCollectionView()
                    return configureInputBarIfNeeded()
                } catch {
                    return Logger.log(
                        error,
                        domain: .conversation
                    )
                }
            }

            guard matchesCurrentConversation(updatedConversation.id.key) else { return }

            // If a user was added/removed, resolve the users again.
            if previousParticipantCount != updatedConversation.participants.count {
                do throws(Exception) {
                    try await updatedConversation.resolveUsers(forceUpdate: true)
                } catch {
                    Logger.log(
                        error,
                        domain: .conversation,
                        with: .toastInPrerelease
                    )
                }
            }

            clientSession.conversation.setCurrentConversation(updatedConversation)
            chatPageState.setIsWaitingToUpdateConversations(false) // Allow typing indicator to appear.

            if chatPageViewService.recipientBar?.layout.recipientBarView == nil,
               let navigationTitle = ConversationCellViewData(
                   updatedConversation,
                   useCachedValue: previousParticipantCount == updatedConversation.participants.count
               )?.titleLabelText {
                chatPageViewService.setNavigationTitle(navigationTitle)
            }

            guard previousConversationHash != updatedConversation.id.hash else { return }
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
