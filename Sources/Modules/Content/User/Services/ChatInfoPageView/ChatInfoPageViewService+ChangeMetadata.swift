//
//  ChatInfoPageViewService+ChangeMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem

public extension ChatInfoPageViewService {
    // MARK: - Present Change Metadata Action Sheet

    /// `.changeMetadataButtonTapped`
    func presentChangeMetadataActionSheet() async -> MetadataChangeType? {
        await withCheckedContinuation { continuation in
            presentChangeMetadataActionSheet { continuation.resume(returning: $0) }
        }
    }

    private func presentChangeMetadataActionSheet(completion: @escaping (MetadataChangeType?) -> Void) {
        Task { @MainActor in
            func presentChangeNameAlert() async -> MetadataChangeType? {
                var conversationName: String?
                if let name = conversation?.metadata.name,
                   !name.isBangQualifiedEmpty {
                    conversationName = name
                }

                let input = await AKTextInputAlert(
                    message: "Choose a new name for this conversation:",
                    attributes: .init(
                        clearButtonMode: .always,
                        sampleText: conversationName
                    ),
                    cancelButtonTitle: Localized(.cancel).wrappedValue,
                    confirmButtonTitle: Localized(.done).wrappedValue
                ).present(translating: [.message])

                guard let conversation,
                      let name = input,
                      name != conversation.metadata.name,
                      !(name.isBangQualifiedEmpty && conversation.metadata.name.isBangQualifiedEmpty) else { return nil }

                let sanitizedName = name.isBangQualifiedEmpty ? .bangQualifiedEmpty : name
                let newMetadata: ConversationMetadata = .init(
                    name: sanitizedName.trimmingBorderedWhitespace,
                    imageData: conversation.metadata.imageData,
                    isPenPalsConversation: conversation.metadata.isPenPalsConversation,
                    lastModifiedDate: conversation.metadata.lastModifiedDate,
                    messageRecipientConsentAcknowledgementData: conversation.metadata.messageRecipientConsentAcknowledgementData,
                    penPalsSharingData: conversation.metadata.penPalsSharingData,
                    requiresConsentFromInitiator: conversation.metadata.requiresConsentFromInitiator
                )

                return .name(newMetadata)
            }

            func presentChangePhotoAlert() async -> MetadataChangeType? {
                var photoChangeType: MetadataChangeType?

                let takePhotoAction: AKAction = .init("Take photo") {
                    photoChangeType = .selectPhotoFromCamera
                }

                let chooseFromLibraryAction: AKAction = .init("Choose photo from library") {
                    photoChangeType = .selectPhotoFromLibrary
                }

                await AKActionSheet(
                    actions: [takePhotoAction, chooseFromLibraryAction],
                    cancelButtonTitle: Localized(.cancel).wrappedValue
                ).present(translating: [.actions()])
                return photoChangeType
            }

            @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?

            var didComplete = false
            var canComplete: Bool {
                guard !didComplete else { return false }
                didComplete = true
                return true
            }

            let changeNameAction: AKAction = .init("Change name") {
                Task {
                    guard canComplete else { return }
                    completion(await presentChangeNameAlert())
                }
            }

            let changePhotoAction: AKAction = .init("Change photo") {
                Task {
                    guard canComplete else { return }
                    completion(await presentChangePhotoAlert())
                }
            }

            let removePhotoAction: AKAction = .init("Remove photo", style: .destructive) {
                guard let conversation,
                      canComplete else { return }

                let newMetadata: ConversationMetadata = .init(
                    name: conversation.metadata.name,
                    imageData: nil,
                    isPenPalsConversation: conversation.metadata.isPenPalsConversation,
                    lastModifiedDate: conversation.metadata.lastModifiedDate,
                    messageRecipientConsentAcknowledgementData: conversation.metadata.messageRecipientConsentAcknowledgementData,
                    penPalsSharingData: conversation.metadata.penPalsSharingData,
                    requiresConsentFromInitiator: conversation.metadata.requiresConsentFromInitiator
                )

                completion(.removePhoto(newMetadata))
            }

            var actions: [AKAction] = [changeNameAction, changePhotoAction]
            if conversation?.metadata.imageData != nil {
                actions.append(removePhotoAction)
            }

            await AKActionSheet(
                actions: actions,
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions()])

            guard canComplete else { return }
            completion(nil)
        }
    }
}
