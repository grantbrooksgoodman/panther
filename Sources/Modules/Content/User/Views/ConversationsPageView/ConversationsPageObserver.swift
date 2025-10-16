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

public struct ConversationsPageObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = ConversationsPageReducer

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [
        Observables.traitCollectionChanged,
        Observables.updatedContactPairArchive,
        Observables.updatedCurrentUser,
    ]
    public let viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(ConversationsPageObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            sender: self
        )

        switch observable.key {
        case .traitCollectionChanged,
             .updatedContactPairArchive:
            send(.traitCollectionChanged)

        case .updatedCurrentUser:
            guard chatPageState.isPresented else {
                updateConversations()
                return
            }

            chatPageState.addEffectUponIsPresented(changedTo: false, id: .updateCurrentUser) { send(.updatedCurrentUser) }
            chatPageState.addEffectUponIsWaitingToUpdateConversations(changedTo: true, id: .updateConversations) { updateConversations() }

        default: ()
        }
    }

    public func send(_ action: ConversationsPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }

    // MARK: - Auxiliary

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

            let resolveCurrentUserResult = await clientSession.user.resolveCurrentUser()

            switch resolveCurrentUserResult {
            case let .failure(exception):
                Logger.log(
                    exception,
                    domain: .conversation,
                    with: .toastInPrerelease
                )

            default: ()
            }

            if let exception = await clientSession.user.currentUser?.setConversations() {
                Logger.log(
                    exception,
                    domain: .conversation,
                    with: .toastInPrerelease
                )
            }

            if let exception = await clientSession.user.currentUser?.conversations?.visibleForCurrentUser.setUsers() {
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

            guard chatPageState.isPresented else {
                send(.updatedCurrentUser)
                return
            }

            if let currentConversation = clientSession.conversation.fullConversation,
               let updatedConversation = clientSession.user.currentUser?.conversations?.first(where: { $0.id.key == currentConversation.id.key }) {
                guard let currentMessages = currentConversation.messages,
                      let missingMessages = updatedConversation.messages?
                      .filter({ !currentMessages.contains($0) })
                      .filter({ !$0.isFromCurrentUser })
                      .filter({ $0.currentUserReadReceipt == nil }),
                      !missingMessages.isEmpty else {
                    guard clientSession.conversation.currentConversation?.id.key == updatedConversation.id.key else { return }
                    clientSession.conversation.setCurrentConversation(updatedConversation)
                    chatPageState.setIsWaitingToUpdateConversations(false) // Allow typing indicator to appear.

                    guard currentConversation.id.hash != updatedConversation.id.hash else { return }
                    if let navigationTitle = ConversationCellViewData(updatedConversation)?.titleLabelText {
                        chatPageViewService.setNavigationTitle(navigationTitle)
                    }

                    chatPageViewService.reloadCollectionView() // Reload to display updated read date / reactions.
                    Observables.currentConversationMetadataChanged.trigger()
                    return
                }

                let updateReadDateResult = await updatedConversation.updateReadDate(for: missingMessages)

                switch updateReadDateResult {
                case let .success(conversation):
                    if let badgeNumber = await clientSession.user.currentUser?.calculateBadgeNumber(),
                       let exception = await notificationService.setBadgeNumber(badgeNumber) {
                        Logger.log(exception, domain: .conversation)
                    }

                    guard clientSession.conversation.currentConversation?.id.key == conversation.id.key else { return }
                    clientSession.conversation.setCurrentConversation(conversation)
                    chatPageViewService.reloadCollectionView()

                case let .failure(exception):
                    Logger.log(exception, domain: .conversation)
                }
            }

            chatPageState.setIsWaitingToUpdateConversations(false)
        }
    }
}
