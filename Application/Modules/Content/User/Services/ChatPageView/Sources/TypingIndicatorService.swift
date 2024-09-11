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

public final class TypingIndicatorService {
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

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Object Lifecycle

    deinit {
        stopCheckingForTypingIndicatorChanges()
    }

    // MARK: - Text View Did Change

    @MainActor
    public func textViewDidChange(to text: String) async -> Exception? {
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

    public func startCheckingForTypingIndicatorChanges() {
        typingIndicatorTimer = .scheduledTimer(
            timeInterval: .init(Floats.timerTimeInterval),
            target: self,
            selector: #selector(checkForTypingIndicatorChanges),
            userInfo: nil,
            repeats: true
        )
    }

    public func stopCheckingForTypingIndicatorChanges() {
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
    }

    // MARK: - Auxiliary

    @objc
    private func checkForTypingIndicatorChanges() {
        guard !chatPageState.isWaitingToUpdateConversations else { return }

        @Persistent(.currentUserID) var currentUserID: String?
        guard let conversation = viewController.currentConversation,
              conversation.participants.filter({ $0.userID != currentUserID }).contains(where: { $0.isTyping }) else {
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
        guard let conversation = viewController.currentConversation,
              conversation.participants.count == 2 else { return nil }

        guard let currentUserParticipant = conversation.currentUserParticipant else {
            return .init(
                "Failed to resolve current user participant.",
                metadata: [self, #file, #function, #line]
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
