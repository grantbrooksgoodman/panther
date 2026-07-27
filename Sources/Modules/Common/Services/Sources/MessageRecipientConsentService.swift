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

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.chatPageViewService.inputBar) private var inputBarService: InputBarService?
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.uiApplication.presentedViews) private var presentedViews: [UIView]

    // MARK: - Send Consent Message in Current Conversation

    func sendConsentMessageInCurrentConversation() async throws(Exception) {
        guard let conversation = entitySession.conversation.currentConversation,
              let currentUser = entitySession.user.currentUser else {
            throw Exception(
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

        guard !conversation.currentUserInitiatorRequiresMessageReceiptConsent else {
            return try await messageDeliveryService.sendTextMessage(
                consentMessage
            )
        }

        let acknowledgeAction: AKAction = .init(Localized(.acknowledgeConsent).wrappedValue) {
            Task { @MainActor in
                do throws(Exception) {
                    try await self.acknowledgeConsent(
                        forUser: currentUser,
                        inConversation: conversation
                    )

                    try await self.messageDeliveryService.sendTextMessage(
                        consentMessage
                    )
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
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
    }

    // MARK: - Set Message Recipient Consent Required

    func setMessageRecipientConsentRequired(
        _ messageRecipientConsentRequired: Bool
    ) async throws(Exception) {
        guard let currentUser = entitySession.user.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        _ = try await currentUser.update(
            \.messageRecipientConsentRequired,
            to: messageRecipientConsentRequired
        )
    }

    // MARK: - Auxiliary

    private func acknowledgeConsent(
        forUser user: User,
        inConversation conversation: Conversation
    ) async throws(Exception) {
        let participantUserIDs = conversation.participants.map(\.userID)
        let userID = user.id

        // Atomically read-modify-write the acknowledgement
        // data so concurrent acknowledgements from other
        // participants are never overwritten.
        _ = try await conversation.update(
            \.metadata,
            applyingRaw: { currentValue in
                typealias MetadataKey = ConversationMetadata.SerializableKey

                guard var metadata = currentValue as? [String: Any],
                      let encodedAcknowledgementData = metadata[
                          MetadataKey.messageRecipientConsentAcknowledgementData.rawValue
                      ] as? [String] else { return currentValue }

                // Parse "<userID>: <acknowledged>" entries.
                var acknowledgementsByUserID = [String: Bool]()
                for entry in encodedAcknowledgementData {
                    let components = entry.components(separatedBy: ": ")
                    guard components.count == 2 else { continue }
                    acknowledgementsByUserID[components[0]] = components[1] != false.description
                }

                acknowledgementsByUserID[userID] = true

                // Once all non-initiator participants have
                // acknowledged, consent is fully granted and
                // the requirement resets in the same
                // transaction.
                if let initiatorUserID = metadata[
                    MetadataKey.requiresConsentFromInitiator.rawValue
                ] as? String,
                    !initiatorUserID.isBangQualifiedEmpty,
                    acknowledgementsByUserID
                    .filter({ $0.key != initiatorUserID })
                    .allSatisfy(\.value) {
                    metadata[MetadataKey.requiresConsentFromInitiator.rawValue] = String.bangQualifiedEmpty
                    acknowledgementsByUserID = participantUserIDs.reduce(
                        into: [String: Bool]()
                    ) { $0[$1] = true }
                }

                metadata[MetadataKey.messageRecipientConsentAcknowledgementData.rawValue] = acknowledgementsByUserID
                    .map { "\($0.key): \($0.value ? String.bangQualifiedEmpty : false.description)" }
                    .sorted()

                return metadata
            }
        )
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
