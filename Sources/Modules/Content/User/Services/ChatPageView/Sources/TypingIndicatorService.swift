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
import Networking

final class TypingIndicatorService: @unchecked Sendable {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.TypingIndicator

    // MARK: - Types

    private enum TaskID: String {
        case updateIsTyping = "updateIsTypingForCurrentUser"
    }

    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var changeHandlerID: UUID?
    private var isUpdatingIsTypingForCurrentUser = false

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
        changeHandlerID = SessionStore.addChangeHandler { [weak self] change in
            guard let self else { return }
            handleStoreChange(change)
        }
    }

    // MARK: - Object Lifecycle

    deinit {
        if let changeHandlerID {
            SessionStore.removeChangeHandler(changeHandlerID)
        }
    }

    // MARK: - Reset Typing Indicator Status for Current User

    static func resetTypingIndicatorStatusForCurrentUser() async throws(Exception) {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        @Dependency(\.networking.database) var database: DatabaseDelegate

        guard let currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        guard let conversations = currentUser
            .conversations?
            .filter({ $0.currentUserParticipant?.isTyping ?? false }),
            !conversations.isEmpty else { return }

        // Single fan-out for all conversations where the
        // current user is typing.
        var updates = [String: Any]()
        for conversation in conversations {
            guard let participant = conversation.currentUserParticipant else { continue }
            let path = [
                NetworkPath.conversations.rawValue,
                conversation.id.key,
                Conversation.SerializableKey.participants.rawValue,
                participant.userID,
                Participant.SerializableKey.isTyping.rawValue,
            ].joined(separator: "/")

            updates[path] = false
        }

        try await database.commit(updates)
    }

    // MARK: - Text View Did Change

    @MainActor
    func textViewDidChange(
        to text: String
    ) async throws(Exception) {
        let exception: Exception? = await withUnsafeContinuation { continuation in
            _textViewDidChange(to: text) { exception in
                continuation.resume(returning: exception)
            }
        }

        if let exception {
            throw exception
        }
    }

    @MainActor
    private func _textViewDidChange(
        to text: String,
        completion: @escaping (Exception?) -> Void
    ) {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.updateIsTyping.rawValue)",
            delay: text.isBlank ? .zero : .milliseconds(Floats.debounceDurationMilliseconds),
            priority: .background
        ) { @MainActor [weak self] in
            guard let self,
                  !isUpdatingIsTypingForCurrentUser else { return completion(nil) }
            isUpdatingIsTypingForCurrentUser = true

            var didComplete = false
            var canComplete: Bool {
                guard !didComplete else { return false }
                didComplete = true
                return true
            }

            guard !messageDeliveryService.isSendingMessage else {
                isUpdatingIsTypingForCurrentUser = false
                return messageDeliveryService.addEffectUponIsSendingMessage(
                    changedTo: false,
                    id: .updateIsTypingForCurrentUser
                ) {
                    self._textViewDidChange(to: text) { exception in
                        completion(exception)
                    }
                }
            }

            do throws(Exception) {
                try await self.updateIsTypingForCurrentUser(!text.isBlank)
                self.isUpdatingIsTypingForCurrentUser = false
                guard canComplete else { return }
                completion(nil)
            } catch {
                isUpdatingIsTypingForCurrentUser = false
                guard canComplete else { return }
                completion(error)
            }
        }
    }

    // MARK: - Auxiliary

    @MainActor
    private func checkForTypingIndicatorChanges() {
        guard canSafelyToggleTypingIndicator else { return }

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
    private func handleStoreChange(_ change: SessionStoreChange) {
        guard case let .conversations(upsertedIDKeys, _) = change,
              let currentConversation = viewController.currentConversation,
              upsertedIDKeys.contains(currentConversation.id.key) else { return }
        checkForTypingIndicatorChanges()
    }

    @MainActor
    private func updateIsTypingForCurrentUser(
        _ isTyping: Bool
    ) async throws(Exception) {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        guard let conversation = clientSession.conversation.currentConversation,
              conversation.participants.count == Int(Floats.participantCountThreshold) else { return }

        guard let currentUserParticipant = conversation.currentUserParticipant else {
            throw Exception(
                "Failed to resolve current user participant.",
                metadata: .init(sender: self)
            )
        }

        guard isTyping != currentUserParticipant.isTyping else { return }

        // Single-field fan-out write instead of replacing
        // the entire participants array.
        let path = [
            NetworkPath.conversations.rawValue,
            conversation.id.key,
            Conversation.SerializableKey.participants.rawValue,
            currentUserParticipant.userID,
            Participant.SerializableKey.isTyping.rawValue,
        ].joined(separator: "/")
        try await database.commit([path: isTyping])
    }
}
