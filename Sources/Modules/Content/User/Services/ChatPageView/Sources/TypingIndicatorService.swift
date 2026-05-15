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

    private let viewController: ChatPageViewController

    private var isUpdatingIsTypingForCurrentUser = false
    private var typingIndicatorTimer: Timer?

    // MARK: - Computed Properties

    @MainActor
    private var canSafelyToggleTypingIndicator: Bool {
        guard let messagesDataSource = viewController
            .messagesCollectionView
            .messagesDataSource else { return false }

        let sectionsFromCollectionView = viewController
            .messagesCollectionView
            .numberOfSections

        let sectionsFromDataSource = messagesDataSource.numberOfSections(
            in: viewController.messagesCollectionView
        )

        guard sectionsFromCollectionView > 0 else { return false }

        if viewController.isTypingIndicatorHidden {
            return sectionsFromDataSource == sectionsFromCollectionView
        } else {
            return sectionsFromDataSource == (sectionsFromCollectionView - 1)
        }
    }

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

        return await conversations.parallelMap(
            failFast: false
        ) {
            guard let currentUserParticipant = $0.currentUserParticipant else { return nil }

            var newParticipants = $0.participants.filter { $0 != currentUserParticipant }
            newParticipants.append(.init(
                userID: currentUserParticipant.userID,
                hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
                isTyping: false
            ))

            do throws(Exception) {
                _ = try await $0.update(
                    \.participants,
                    to: newParticipants
                )
                return nil
            } catch {
                return error
            }
        }
    }

    // MARK: - Text View Did Change

    @MainActor
    func textViewDidChange(to text: String) async -> Exception? {
        await withUnsafeContinuation { continuation in
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

    @MainActor
    func startCheckingForTypingIndicatorChanges() {
        stopCheckingForTypingIndicatorChanges()
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

    @MainActor
    @objc
    private func checkForTypingIndicatorChanges() {
        guard !chatPageState.isWaitingToUpdateConversations,
              canSafelyToggleTypingIndicator else { return }

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
        do {
            let updatedConversation = try await conversation.update(
                \.participants,
                to: newParticipants
            )

            clientSession.user.startObservingCurrentUserChanges()
            guard clientSession.conversation.currentConversation?.id.key == updatedConversation.id.key else { return nil }

            clientSession.conversation.setCurrentConversation(updatedConversation)
            return nil
        } catch {
            clientSession.user.startObservingCurrentUserChanges()
            return error
        }
    }
}
