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
        let sendTextMessageResult = await clientSession.message.sendTextMessage(
            text,
            toUsers: users,
            inConversation: conversation
        )
        toggleSendingUI(inputBar, on: false)

        switch sendTextMessageResult {
        case let .success(conversation):
            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            return exception
        }
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
}
