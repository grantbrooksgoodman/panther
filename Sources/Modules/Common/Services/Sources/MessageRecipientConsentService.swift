//
//  MessageRecipientConsentService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

@MainActor
final class MessageRecipientConsentService {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.chatPageViewService.inputBar) private var inputBarService: InputBarService?
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.uiApplication.presentedViews) private var presentedViews: [UIView]

    // MARK: - Send Consent Message in Current Conversation

    func sendConsentMessageInCurrentConversation() async -> Exception? {
        guard let conversation = clientSession.conversation.fullConversation,
              let currentUser = clientSession.user.currentUser else {
            return .init(
                "Failed to resolve either conversation or current user.",
                metadata: .init(sender: self)
            )
        }

        inputBarService?.setConsentButtonIsEnabled(false)
        let consentMessage = Localized(
            conversation.currentUserInitiatorRequiresMessageReceiptConsent ?
                .messageRecipientConsentRequestMessage :
                .messageRecipientConsentAcknowledgementMessage
        ).wrappedValue

        defer {
            messageDeliveryService.addEffectUponIsSendingMessage(changedTo: false, id: .configureInputBar) { self.isSendingMessageFalseEffect() }
            messageDeliveryService.addEffectUponIsSendingMessage(changedTo: true, id: .configureInputBar) { self.isSendingMessageTrueEffect() }
        }

        guard !conversation.currentUserInitiatorRequiresMessageReceiptConsent else { return await messageDeliveryService.sendTextMessage(consentMessage) }

        let acknowledgeAction: AKAction = .init(Localized(.acknowledgeConsent).wrappedValue) {
            Task { @MainActor in
                if let exception = await self.acknowledgeConsent(forUser: currentUser, inConversation: conversation) {
                    Logger.log(exception, with: .toast)
                }

                if let exception = await self.messageDeliveryService.sendTextMessage(consentMessage) {
                    Logger.log(exception, with: .toast)
                }
            }
        }

        let cancelAction: AKAction = .init(Localized(.cancel).wrappedValue, style: .cancel) {
            Task { @MainActor in
                self.inputBarService?.setConsentButtonIsEnabled(true)
            }
        }

        await AKActionSheet(
            actions: [acknowledgeAction, cancelAction],
            sourceItem: .custom(.view(
                presentedViews.first(where: {
                    $0.tag == coreUI.semTag(
                        for: AppConstants
                            .Strings
                            .ChatPageViewService
                            .InputBar
                            .consentButtonSemanticTag
                    )
                })
            ))
        ).present(translating: [])
        return nil
    }

    // MARK: - Set Message Recipient Consent Required

    func setMessageRecipientConsentRequired(_ messageRecipientConsentRequired: Bool) async -> Exception? {
        guard let currentUser = clientSession.user.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        do {
            return try await clientSession.user.setCurrentUser(
                currentUser.update(
                    \.messageRecipientConsentRequired,
                    to: messageRecipientConsentRequired
                ),
                repopulateValuesIfNeeded: true
            )
        } catch {
            return error
        }
    }

    // MARK: - Auxiliary

    private func acknowledgeConsent(
        forUser user: User,
        inConversation conversation: Conversation
    ) async -> Exception? {
        let newUserAcknowledgementData: MessageRecipientConsentAcknowledgementData = .init(
            userID: user.id,
            consentAcknowledged: true
        )

        let currentAcknowledgementData = conversation.metadata.messageRecipientConsentAcknowledgementData
        var newAcknowledgementData = currentAcknowledgementData.filter { $0.userID != user.id }
        newAcknowledgementData.append(newUserAcknowledgementData)

        let emptyAcknowledgementData = MessageRecipientConsentAcknowledgementData.empty(userIDs: conversation.participants.map(\.userID))
        if let initatorUserID = conversation.metadata.requiresConsentFromInitiator,
           newAcknowledgementData.filter({ $0.userID != initatorUserID }).allSatisfy(\.consentAcknowledged) {
            newAcknowledgementData = emptyAcknowledgementData
        }

        do {
            try await clientSession.conversation.setCurrentConversation(
                conversation.update(
                    \.metadata,
                    to: conversation.metadata.copyWith(
                        messageRecipientConsentAcknowledgementData: newAcknowledgementData,
                        nilRequiresConsentFromInitiator: newAcknowledgementData == emptyAcknowledgementData
                    )
                )
            )
            return nil
        } catch {
            return error
        }
    }

    private func isSendingMessageFalseEffect() {
        inputBarService?.configureInputBar()
        Message.consentRequestMessageID = nil
    }

    private func isSendingMessageTrueEffect() {
        inputBarService?.setConsentButtonIsEnabled(false)
        Task.delayed(by: .seconds(1)) { @MainActor in
            guard messageDeliveryService.isSendingMessage else { return }
            inputBarService?.configureInputBar()
        }
    }
}
