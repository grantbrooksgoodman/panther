//
//  InputBarAccessoryViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import InputBarAccessoryView
import Redux

public struct InputBarAccessoryViewService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession

    // MARK: - Properties

    private var conversation: Conversation? { clientSession.conversation.currentConversation }

    // MARK: - Did Press Send Button

    public func didPressSendButton(_ inputBar: InputBarAccessoryView, text: String) async -> Exception? {
        guard let conversation,
              let users = conversation.users else { return nil }

        addMockMessageToCurrentConversation(text)

        toggleSendingUI(inputBar, on: true)
        chatPageViewService.deliveryProgression?.startAnimatingDeliveryProgress()

        let sendTextMessageResult = await clientSession.message.sendTextMessage(
            text,
            toUsers: users,
            inConversation: conversation
        )

        toggleSendingUI(inputBar, on: false)
        chatPageViewService.deliveryProgression?.stopAnimatingDeliveryProgress()

        switch sendTextMessageResult {
        case let .success(conversation):
            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Text View Did Change

    public func textViewDidChange(to text: String) async -> Exception? {
        await updateIsTypingForCurrentUser(!text.isBlank)
    }

    // MARK: - Auxiliary

    private func addMockMessageToCurrentConversation(_ text: String) {
        guard let conversation,
              var messages = conversation.messages,
              let currentUser = clientSession.user.currentUser else { return }

        messages.append(.init(
            UserContentConstants.newMessageID,
            fromAccountID: currentUser.id,
            hasAudioComponent: false,
            audioComponents: nil,
            translations: [.init(input: .init(text), output: text, languagePair: .system)],
            readDate: nil,
            sentDate: Date()
        ))

        let newConversation: Conversation = .init(
            conversation.id,
            messageIDs: conversation.messageIDs,
            messages: messages,
            lastModifiedDate: conversation.lastModifiedDate,
            participants: conversation.participants,
            users: conversation.users
        )

        clientSession.conversation.setCurrentConversation(newConversation)
        chatPageViewService.reloadCollectionView()
    }

    private func toggleSendingUI(_ inputBar: InputBarAccessoryView, on: Bool) {
        Task { @MainActor in
            if on {
                inputBar.inputTextView.text = ""
                inputBar.sendButton.startAnimating()
            } else {
                inputBar.sendButton.stopAnimating()
            }

            inputBar.inputTextView.tintColor = on ? .clear : .accent
            inputBar.sendButton.isEnabled = on ? false : true
            inputBar.sendButton.isUserInteractionEnabled = on ? false : true
        }
    }

    private func updateIsTypingForCurrentUser(_ isTyping: Bool) async -> Exception? {
        @Persistent(.currentUserID) var currentUserID: String?

        guard let conversation,
              conversation.participants.count == 2 else { return nil }

        guard let currentUserParticipant = conversation.participants.first(where: { $0.userID == currentUserID }) else {
            return .init(
                "Failed to find current user in conversation participants.",
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
            clientSession.conversation.setCurrentConversation(conversation)
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
