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
        case name(ConversationMetadata)
        case removePhoto(ConversationMetadata)
        case selectPhotoFromCamera
        case selectPhotoFromLibrary
    }

    private enum CacheKey: String, CaseIterable {
        case chatParticipantsForUserIDs
    }

    // MARK: - Dependencies

    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.quickViewer) private var quickViewer: QuickViewer

    // MARK: - Properties

    public private(set) var isPreviewingMedia = false

    @Cached(CacheKey.chatParticipantsForUserIDs) private var cachedChatParticipantsForUserIDs: [String: ChatParticipant]?

    // MARK: - Get Chat Participants

    /// `.viewAppeared`
    public func getChatParticipants() async -> Callback<[ChatParticipant], Exception> {
        @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?

        guard let conversation else {
            return .failure(.init("No current conversation.", metadata: [self, #file, #function, #line]))
        }

        guard let users = conversation.users else {
            if let exception = await conversation.setUsers() {
                return .failure(exception)
            }

            return await getChatParticipants()
        }

        var chatParticipants = [ChatParticipant]()

        for user in users {
            if !conversation.metadata.isPenPalsConversation,
               let cachedChatParticipantsForUserIDs,
               let cachedChatParticipant = cachedChatParticipantsForUserIDs[user.id] {
                chatParticipants.append(cachedChatParticipant)
                continue
            }

            var chatParticipant: ChatParticipant?
            let currentUserSharesData = conversation.currentUserSharesPenPalsData(with: user)
            // swiftlint:disable:next identifier_name
            let currentUserDoesNotShareDataButOtherUserDoes = !currentUserSharesData && conversation.userSharesPenPalsDataWithCurrentUser(user)

            @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService
            if !conversation.metadata.isPenPalsConversation
                || conversation.mutuallySharedPenPalsDataBetweenCurrentUserAnd(user)
                || currentUserDoesNotShareDataButOtherUserDoes
                || penPalsService.isKnownToCurrentUser(user.id) {
                let isPenPal = !conversation.mutuallySharedPenPalsDataBetweenCurrentUserAnd(user) &&
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
                        penPalsStatus: isPenPal ? (currentUserSharesData ? .currentUserSharesData : .currentUserDoesNotShareData) : nil
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
                        penPalsStatus: isPenPal ? (currentUserSharesData ? .currentUserSharesData : .currentUserDoesNotShareData) : nil
                    )
                }
            } else {
                chatParticipant = .init(
                    displayName: user.penPalsName,
                    cnContactContainer: nil,
                    contactPair: .withUser(user, name: user.penPalsName),
                    penPalsStatus: currentUserSharesData ? .currentUserSharesData : .currentUserDoesNotShareData
                )
            }

            guard let chatParticipant else { continue }
            chatParticipants.append(chatParticipant)

            guard !conversation.metadata.isPenPalsConversation else { continue }
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

    // MARK: - Media Item View Tapped

    public func mediaItemViewTapped(
        _ metadata: MediaItemView.Metadata,
        filePaths: [String],
        startingIndex: Int
    ) {
        guard !(UIApplication.isFullyV26Compatible && UIDevice.isSimulator) else { return }

        isPreviewingMedia = true
        quickViewer.preview(
            filesAtPaths: filePaths,
            startingIndex: startingIndex,
            title: Localized(.attachment).wrappedValue,
            embedded: true
        )

        quickViewer.onDismiss {
            NavigationBar.setAppearance(Application.isInPrevaricationMode ? .appDefault : .default())
            self.isPreviewingMedia = false
        }
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cachedChatParticipantsForUserIDs = nil
    }
}
