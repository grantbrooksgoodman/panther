//
//  TypingIndicatorService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

final class TypingIndicatorService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.TypingIndicator

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService

    // MARK: - Properties

    // Bool
    private var isUpdatingIsTypingForCurrentUser = false

    // Other
    private let viewController: ChatPageViewController

    private var typingIndicatorTimer: Timer?

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Object Lifecycle

    deinit {
        stopCheckingForTypingIndicatorChanges()
    }

    // MARK: - Reset Typing Indicator Status for Current User

    static func resetTypingIndicatorStatusForCurrentUser() async -> Exception? {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        guard let currentUser else {
            return .init("Current user has not been set.", metadata: .init(sender: self))
        }

        guard let conversations = currentUser
            .conversations?
            .filter({ $0.currentUserParticipant?.isTyping ?? false }) else { return nil }

        var exceptions = [Exception]()
        for conversation in conversations {
            guard let currentUserParticipant = conversation.currentUserParticipant else { continue }

            var newParticipants = conversation.participants.filter { $0 != currentUserParticipant }
            newParticipants.append(.init(
                userID: currentUserParticipant.userID,
                hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
                isTyping: false
            ))

            let updateValueResult = await conversation.updateValue(newParticipants, forKey: .participants)

            switch updateValueResult {
            case let .failure(exception):
                exceptions.append(exception)

            default: ()
            }
        }

        return exceptions.compiledException
    }

    // MARK: - Text View Did Change

    @MainActor
    func textViewDidChange(to text: String) async -> Exception? {
        return await withUnsafeContinuation { continuation in
            _textViewDidChange(to: text) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    @MainActor
    private func _textViewDidChange(to text: String, completion: @escaping (Exception?) -> Void) {
        Task.background { @MainActor in
            guard !isUpdatingIsTypingForCurrentUser else { return completion(nil) }
            isUpdatingIsTypingForCurrentUser = true

            var didComplete = false
            var canComplete: Bool {
                guard !didComplete else { return false }
                didComplete = true
                return true
            }

            guard !messageDeliveryService.isSendingMessage else {
                isUpdatingIsTypingForCurrentUser = false
                messageDeliveryService.addEffectUponIsSendingMessage(changedTo: false, id: .updateIsTypingForCurrentUser) {
                    self._textViewDidChange(to: text) { exception in
                        completion(exception)
                    }
                }
                return
            }

            let exception = await self.updateIsTypingForCurrentUser(!text.isBlank)
            self.isUpdatingIsTypingForCurrentUser = false
            guard canComplete else { return }
            completion(exception)
        }
    }

    // MARK: - Typing Indicator Timer

    func startCheckingForTypingIndicatorChanges() {
        typingIndicatorTimer = .scheduledTimer(
            timeInterval: .init(Floats.timerTimeInterval),
            target: self,
            selector: #selector(checkForTypingIndicatorChanges),
            userInfo: nil,
            repeats: true
        )
    }

    func stopCheckingForTypingIndicatorChanges() {
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
    }

    // MARK: - Auxiliary

    @objc
    private func checkForTypingIndicatorChanges() {
        guard !chatPageState.isWaitingToUpdateConversations else { return }

        // FIXME: Still encounter crashing bugs with this. Seems to be a MessageKit issue.
        // https://github.com/MessageKit/MessageKit/issues/1788
        guard viewController
            .currentConversation?
            .participants
            .filter({ $0.userID != User.currentUserID })
            .contains(where: \.isTyping) == true else {
            guard !viewController.isTypingIndicatorHidden else { return }
            viewController.setTypingIndicatorViewHidden(true, animated: true)
            return
        }

        guard viewController.isTypingIndicatorHidden else { return }
        viewController.setTypingIndicatorViewHidden(false, animated: true)
        viewController.messagesCollectionView.scrollToLastItem(animated: true)
    }

    @MainActor
    private func updateIsTypingForCurrentUser(_ isTyping: Bool) async -> Exception? {
        guard let conversation = clientSession.conversation.fullConversation,
              conversation.participants.count == 2 else { return nil }

        guard let currentUserParticipant = conversation.currentUserParticipant else {
            return .init(
                "Failed to resolve current user participant.",
                metadata: .init(sender: self)
            )
        }

        guard isTyping != currentUserParticipant.isTyping else { return nil }

        var newParticipants = conversation.participants.filter { $0 != currentUserParticipant }
        newParticipants.append(.init(
            userID: currentUserParticipant.userID,
            hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
            isTyping: isTyping
        ))

        clientSession.user.stopObservingCurrentUserChanges()
        let updateValueResult = await conversation.updateValue(newParticipants, forKey: .participants)
        clientSession.user.startObservingCurrentUserChanges()

        switch updateValueResult {
        case let .success(conversation):
            guard clientSession.conversation.currentConversation?.id.key == conversation.id.key else { return nil }
            clientSession.conversation.setCurrentConversation(conversation)
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
