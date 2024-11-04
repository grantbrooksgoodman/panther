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
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [
        Observables.traitCollectionChanged,
        Observables.updatedContactPairArchive,
        Observables.updatedCurrentUser,
    ]
    public let viewModel: ViewModel<R>

    // MARK: - Init

    public init(_ viewModel: ViewModel<R>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(ConversationsPageObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value as? Nil != nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            metadata: [self, #file, #function, #line]
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

    public func send(_ action: R.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }

    // MARK: - Auxiliary

    private func updateConversations() {
        Task { @MainActor in
            networking.database.setGlobalCacheStrategy(.returnCacheOnFailure)
            networking.storage.setGlobalCacheStrategy(.returnCacheOnFailure)

            let resolveCurrentUserResult = await clientSession.user.resolveCurrentUser()

            switch resolveCurrentUserResult {
            case let .failure(exception):
                Logger.log(exception, with: .toast())

            default: ()
            }

            if let exception = await clientSession.user.currentUser?.setConversations() {
                Logger.log(exception, with: .toast())
            }

            if let exception = await clientSession.user.currentUser?.conversations?.visibleForCurrentUser.setUsers() {
                Logger.log(exception, with: .toast())
            }

            defer {
                networking.database.setGlobalCacheStrategy(nil)
                networking.storage.setGlobalCacheStrategy(nil)
            }

            guard chatPageState.isPresented else {
                send(.updatedCurrentUser)
                return
            }

            if let currentConversation = clientSession.conversation.currentConversation,
               let updatedConversation = clientSession.user.currentUser?.conversations?.first(where: { $0.id.key == currentConversation.id.key }) {
                guard let currentMessages = currentConversation.messages,
                      let missingMessages = updatedConversation.messages?
                      .filter({ !currentMessages.contains($0) })
                      .filter({ !$0.isFromCurrentUser })
                      .filter({ $0.readDate == nil }),
                      !missingMessages.isEmpty else {
                    guard clientSession.conversation.currentConversation?.id.key == updatedConversation.id.key else { return }
                    clientSession.conversation.setCurrentConversation(updatedConversation)
                    chatPageState.setIsWaitingToUpdateConversations(false) // Allow typing indicator to appear.

                    let currentAmountOfReadMessages = currentConversation
                        .messages?
                        .filter { updatedConversation.messages?.contains($0) ?? false }
                        .compactMap(\.readDate)
                        .count

                    let updatedAmountOfReadMessages = updatedConversation
                        .messages?
                        .compactMap(\.readDate)
                        .count

                    guard currentAmountOfReadMessages != updatedAmountOfReadMessages else { return }
                    chatPageViewService.reloadCollectionView() // Reload to display updated read date.
                    return
                }

                let updateReadDateResult = await updatedConversation.updateReadDate(for: missingMessages)

                switch updateReadDateResult {
                case let .success(conversation):
                    if let badgeNumber = await clientSession.user.currentUser?.calculateBadgeNumber(),
                       let exception = await notificationService.setBadgeNumber(badgeNumber) {
                        Logger.log(exception)
                    }

                    guard clientSession.conversation.currentConversation?.id.key == conversation.id.key else { return }
                    clientSession.conversation.setCurrentConversation(conversation)
                    chatPageViewService.reloadCollectionView()

                case let .failure(exception):
                    Logger.log(exception)
                }
            }

            chatPageState.setIsWaitingToUpdateConversations(false)
        }
    }
}
