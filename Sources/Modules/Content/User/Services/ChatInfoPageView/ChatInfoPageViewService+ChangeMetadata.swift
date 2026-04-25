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

extension ChatInfoPageViewService {
    // MARK: - Present Change Metadata Action Sheet

    /// `.changeMetadataButtonTapped`
    func presentChangeMetadataActionSheet() async -> MetadataChangeType? {
        await withCheckedContinuation { continuation in
            presentChangeMetadataActionSheet { continuation.resume(returning: $0) }
        }
    }

    private func presentChangeMetadataActionSheet(
        completion: @escaping @Sendable (MetadataChangeType?) -> Void
    ) {
        Task { @MainActor in
            @Sendable
            func presentChangeNameAlert() async -> MetadataChangeType? {
                @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?

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
                return .name(
                    conversation.metadata.copyWith(
                        name: sanitizedName.trimmingBorderedWhitespace
                    )
                )
            }

            @Sendable
            func presentChangePhotoAlert() async -> MetadataChangeType? {
                let photoChangeType = LockIsolated<MetadataChangeType?>(nil)
                let takePhotoAction: AKAction = .init("Take photo") {
                    photoChangeType.wrappedValue = .selectPhotoFromCamera
                }

                let chooseFromLibraryAction: AKAction = .init("Choose photo from library") {
                    photoChangeType.wrappedValue = .selectPhotoFromLibrary
                }

                await AKActionSheet(
                    actions: [takePhotoAction, chooseFromLibraryAction],
                    cancelButtonTitle: Localized(.cancel).wrappedValue,
                    sourceItem: .custom(.string(
                        "Change name and photo".localized
                    ))
                ).present(translating: [.actions()])
                return photoChangeType.wrappedValue
            }

            @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?

            let didComplete = LockIsolated(false)
            var canComplete: Bool {
                didComplete.projectedValue.withValue {
                    guard !$0 else { return false }
                    $0 = true
                    return true
                }
            }

            let changeNameAction: AKAction = .init("Change name") {
                Task { @MainActor in
                    guard canComplete else { return }
                    await completion(presentChangeNameAlert())
                }
            }

            let changePhotoAction: AKAction = .init("Change photo") {
                Task { @MainActor in
                    guard canComplete else { return }
                    await completion(presentChangePhotoAlert())
                }
            }

            let removePhotoAction: AKAction = .init("Remove photo", style: .destructive) {
                guard let conversation,
                      canComplete else { return }

                completion(
                    .removePhoto(
                        conversation.metadata.copyWith(nilImageData: true)
                    )
                )
            }

            var actions: [AKAction] = [changeNameAction, changePhotoAction]
            if conversation?.metadata.imageData != nil {
                actions.append(removePhotoAction)
            }

            await AKActionSheet(
                actions: actions,
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                sourceItem: .custom(.string(
                    "Change name and photo".localized
                ))
            ).present(translating: [.actions()])

            guard canComplete else { return }
            completion(nil)
        }
    }
}
