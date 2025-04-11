//
//  ChatInfoPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

public final class ChatInfoPageViewService {
    // MARK: - Types

    public enum MetadataChangeType {
        case name(String)
        case removePhoto
        case selectPhotoFromCamera
        case selectPhotoFromLibrary
    }

    private enum CacheKey: String, CaseIterable {
        case chatParticipantsForUserIDs
    }

    // MARK: - Dependencies

    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.clientSession.conversation.currentConversation) private var currentConversation: Conversation?
    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool

    // MARK: - Properties

    @Cached(CacheKey.chatParticipantsForUserIDs) private var cachedChatParticipantsForUserIDs: [String: ChatParticipant]?

    // MARK: - Get Chat Participants

    /// `.viewAppeared`
    public func getChatParticipants() async -> Callback<[ChatParticipant], Exception> {
        guard let currentConversation else {
            return .failure(.init("No current conversation.", metadata: [self, #file, #function, #line]))
        }

        guard let users = currentConversation.users else {
            if let exception = await self.currentConversation?.setUsers() {
                return .failure(exception)
            }

            return await getChatParticipants()
        }

        var chatParticipants = [ChatParticipant]()

        for user in users {
            if !currentConversation.metadata.isPenPalsConversation,
               let cachedChatParticipantsForUserIDs,
               let cachedChatParticipant = cachedChatParticipantsForUserIDs[user.id] {
                chatParticipants.append(cachedChatParticipant)
                continue
            }

            var chatParticipant: ChatParticipant?
            // swiftlint:disable:next identifier_name
            let currentUserDoesNotShareDataButOtherUserDoes = !currentConversation.currentUserSharesPenPalsData(with: user)
                && currentConversation.userSharesPenPalsDataWithCurrentUser(user)

            @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService
            if !currentConversation.metadata.isPenPalsConversation
                || currentConversation.mutuallySharedPenPalsDataBetweenCurrentUserAnd(user)
                || currentUserDoesNotShareDataButOtherUserDoes
                || penPalsService.isKnownToCurrentUser(user.id) {
                let isPenPal = !currentConversation.mutuallySharedPenPalsDataBetweenCurrentUserAnd(user) &&
                    !penPalsService.isKnownToCurrentUser(user.id)
                let firstCNContactResult = await contactService.firstCNContact(for: user.phoneNumber)

                switch firstCNContactResult {
                case let .success(cnContact):
                    let contactPair: ContactPair = .init(
                        contact: .init(cnContact),
                        numberPairs: [.init(phoneNumber: user.phoneNumber, users: [user])]
                    )

                    chatParticipant = .init(
                        displayName: contactPair.contact.fullName,
                        cnContactContainer: currentUserDoesNotShareDataButOtherUserDoes ? nil : .init(cnContact.mutableCopy() as? CNMutableContact),
                        contactPair: contactPair,
                        isPenPal: isPenPal
                    )

                case .failure:
                    let cnContact = CNMutableContact()
                    cnContact.phoneNumbers.append(
                        .init(
                            label: nil,
                            value: .init(stringValue: user.phoneNumber.formattedString())
                        )
                    )

                    let contactPair: ContactPair = .init(
                        contact: .init(cnContact),
                        numberPairs: [.init(phoneNumber: user.phoneNumber, users: [user])]
                    )

                    chatParticipant = .init(
                        displayName: contactPair.contact.fullName,
                        cnContactContainer: currentUserDoesNotShareDataButOtherUserDoes ? nil : .init(cnContact, isUnknown: true),
                        contactPair: contactPair,
                        isPenPal: isPenPal
                    )
                }
            } else {
                chatParticipant = .init(
                    displayName: user.penPalsName,
                    cnContactContainer: nil,
                    contactPair: .withUser(user, name: user.penPalsName),
                    isPenPal: true
                )
            }

            guard let chatParticipant else { continue }
            chatParticipants.append(chatParticipant)

            guard !currentConversation.metadata.isPenPalsConversation else { continue }
            if var cachedValue = cachedChatParticipantsForUserIDs {
                cachedValue[user.id] = chatParticipant
                cachedChatParticipantsForUserIDs = cachedValue
            } else {
                cachedChatParticipantsForUserIDs = [user.id: chatParticipant]
            }
        }

        var withAlphabeticalPrefix = [ChatParticipant]()
        var withoutAlphabeticalPrefix = [ChatParticipant]()

        for participant in chatParticipants {
            if let firstCharacter = participant.displayName.first,
               firstCharacter.isLetter {
                withAlphabeticalPrefix.append(participant)
            } else {
                withoutAlphabeticalPrefix.append(participant)
            }
        }

        func sorted(_ participants: [ChatParticipant]) -> [ChatParticipant] { participants.sorted(by: { $0.displayName < $1.displayName }) }
        return .success(sorted(withAlphabeticalPrefix) + sorted(withoutAlphabeticalPrefix))
    }

    // MARK: - Present Change Metadata Action Sheet

    /// `.changeMetadataButtonTapped`
    public func presentChangeMetadataActionSheet() async -> MetadataChangeType? {
        await withCheckedContinuation { continuation in
            presentChangeMetadataActionSheet { continuation.resume(returning: $0) }
        }
    }

    private func presentChangeMetadataActionSheet(completion: @escaping (MetadataChangeType?) -> Void) {
        Task { @MainActor in
            func presentChangeNameAlert() async -> MetadataChangeType? {
                var conversationName: String?
                if let name = currentConversation?.metadata.name,
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

                guard let input else { return nil }
                return .name(input)
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
                guard canComplete else { return }
                completion(.removePhoto)
            }

            var actions: [AKAction] = [changeNameAction, changePhotoAction]
            if currentConversation?.metadata.imageData != nil {
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

    // MARK: - Present PenPals Sharing Data Confirmation Action Sheet

    /// `.penPalParticipantViewTapped`
    /// `.penPalsSharingDataSwitchToggledOn`
    /// - Returns: `true` if the user selected the confirmation option.
    public func presentPenPalsSharingDataConfirmationActionSheet(_ userID: String, displayName: String) async -> String? {
        await withCheckedContinuation { continuation in
            presentPenPalsSharingDataConfirmationActionSheet(userID, displayName: displayName) { userID in
                continuation.resume(returning: userID)
            }
        }
    }

    private func presentPenPalsSharingDataConfirmationActionSheet(
        _ userID: String,
        displayName: String,
        completion: @escaping (String?) -> Void
    ) {
        Task {
            let confirmAction: AKAction = .init("Share Phone Number") {
                completion(userID)
            }

            let cancelAction: AKAction = .init(
                Localized(.cancel).wrappedValue,
                style: .cancel
            ) {
                completion(nil)
            }

            Toast.hide()
            await AKActionSheet(
                title: "Share Phone Number with ⌘\(displayName)⌘?", // swiftlint:disable:next line_length
                message: "Both \(RuntimeStorage.languageCode == "en" ? "PenPals" : "parties") sharing their respective phone numbers unlocks the ability to add each other as contacts.\nThis action cannot be undone.",
                actions: [cancelAction, confirmAction]
            ).present(translating: [.actions([confirmAction]), .message, .title])
        }
    }

    // MARK: - Show PenPals Sharing Status Toast

    /// `.penPalParticipantViewTapped`
    public func showPenPalsSharingStatusToast(_ userID: String, displayName: String) async {
        Toast.show(
            .init(
                .banner(style: .info, appearanceEdge: .bottom),
                title: displayName,
                message: "You have already shared your phone number with this user.",
                perpetuation: .ephemeral(.seconds(5))
            ),
            translating: [.message]
        )
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cachedChatParticipantsForUserIDs = nil
    }
}
