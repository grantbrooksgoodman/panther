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

@MainActor // swiftlint:disable:next type_body_length
final class ChatInfoPageViewService {
    // MARK: - Types

    enum MetadataChangeType {
        case name(ConversationMetadata)
        case removePhoto(ConversationMetadata)
        case selectPhotoFromCamera
        case selectPhotoFromLibrary
    }

    private enum CacheKey: String, CaseIterable {
        case chatParticipantsForUserIDs
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.networking.conversationService.archive) private var conversationArchive: ConversationArchiveService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.quickViewer) private var quickViewer: QuickViewer
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    private(set) var isPreviewingMedia = false

    @Cached(CacheKey.chatParticipantsForUserIDs) private var cachedChatParticipantsForUserIDs: [String: ChatParticipant]?

    // MARK: - Init

    nonisolated init() {}

    // MARK: - Computed Properties

    private var uiSegmentBackgroundViewBackgroundColor: UIColor {
        if Application.isInPrevaricationMode || UIApplication.isFullyV26Compatible {
            return .init(hex: ThemeService.isDarkModeActive ? 0x313136 : 0xE2E2E6)
        }

        return .groupedContentBackground
    }

    private var uiSegmentBackgroundViews: [UIView] {
        uiApplication
            .presentedViews
            .filter { $0.descriptor == "UISegment" }
            .compactMap(\.superview?.superview)
    }

    // MARK: - Get Chat Participants

    /// `.viewAppeared`
    func getChatParticipants() async -> Callback<[ChatParticipant], Exception> {
        guard let conversation = clientSession.conversation.fullConversation else {
            return .failure(.init(
                "No current conversation.",
                metadata: .init(sender: self)
            ))
        }

        guard let users = conversation.users,
              conversation.participants.count - 1 == users.count else {
            if let exception = await conversation.setUsers(forceUpdate: true) {
                return .failure(exception)
            }

            clientSession.conversation.setCurrentConversation(conversation)
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

        func sorted(_ participants: [ChatParticipant]) -> [ChatParticipant] {
            participants.sorted(by: { $0.displayName < $1.displayName })
        }
        return .success(sorted(withAlphabeticalPrefix) + sorted(withoutAlphabeticalPrefix))
    }

    // MARK: - Reducer Action Handlers

    func leaveConversationButtonTapped(_ conversation: Conversation?) {
        Task {
            guard let conversation else { return }
            var conversationName = "⌘\(conversation.metadata.name)⌘"
            if conversationName.sanitized.isBangQualifiedEmpty {
                conversationName = "Conversation"
            }

            guard let currentUserID = User.currentUserID,
                  await AKConfirmationAlert(
                      title: "Leave \(conversationName)",
                      message: "Are you sure you'd like to leave this conversation?",
                      cancelButtonTitle: Localized(.cancel).wrappedValue,
                      confirmButtonStyle: .destructivePreferred
                  ).present(translating: [
                      .confirmButtonTitle,
                      .message,
                      .title,
                  ]) else { return }

            Observables.chatInfoPageLoadingStateUpdated.trigger()
            clientSession.user.stopObservingCurrentUserChanges()
            let removeFromConversationResult = await clientSession.activity.removeFromConversation(
                currentUserID,
                conversation: conversation
            )

            clientSession.user.startObservingCurrentUserChanges()
            switch removeFromConversationResult {
            case .success:
                Application.dismissSheets()
                conversationArchive.removeValue(idKey: conversation.id.key)
                navigation.navigate(to: .userContent(.stack([])))

            case let .failure(exception):
                Logger.log(exception, with: .toast)
            }
        }
    }

    func mediaItemViewTapped(
        _ metadata: MediaItemView.Metadata,
        filePaths: [String],
        startingIndex: Int
    ) {
        isPreviewingMedia = true
        quickViewer.preview(
            filesAtPaths: filePaths,
            startingIndex: startingIndex,
            title: Localized(.attachment).wrappedValue,
            embedded: true
        )

        StatusBar.overrideStyle(.appAware)
        quickViewer.onDismiss {
            NavigationBar.setAppearance(Application.isInPrevaricationMode ? .appDefault : .default())
            self.isPreviewingMedia = false
        }
    }

    func removeUserButtonTapped(
        _ chatParticipant: ChatParticipant,
        conversation: Conversation?
    ) {
        Task {
            guard let conversation,
                  let user = chatParticipant.firstUser else { return }

            guard await AKConfirmationAlert(
                title: user.displayName,
                message: "Are you sure you'd like to remove this person from the conversation?",
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                confirmButtonStyle: .destructivePreferred
            ).present(translating: [
                .confirmButtonTitle,
                .message,
            ]) else { return }

            navigation.navigate(to: .chat(.sheet(.none)))
            Observables.chatInfoPageLoadingStateUpdated.trigger()

            let removeFromConversationResult = await clientSession.activity.removeFromConversation(
                user.id,
                conversation: conversation
            )

            switch removeFromConversationResult {
            case let .success(conversation):
                clientSession.conversation.setCurrentConversation(conversation)
                chatPageViewService.reloadCollectionView()
                Observables.currentConversationActivityChanged.trigger()

            case let .failure(exception):
                Logger.log(exception, with: .toast)
            }
        }
    }

    func traitCollectionChanged() {
        Task.delayed(by: .milliseconds(100)) { @MainActor in
            for uiSegmentBackgroundView in self.uiSegmentBackgroundViews {
                uiSegmentBackgroundView.backgroundColor = self.uiSegmentBackgroundViewBackgroundColor
            }
        }
    }

    /// `.changeMetadataActionSheetDismissed(.name)`
    /// `.changeMetadataActionSheetDismissed(.removePhoto)`
    /// `.selectedImageChanged`
    func updateMetadata(
        _ conversation: Conversation,
        action: Activity.Action,
        newMetadata: ConversationMetadata
    ) async -> Callback<Conversation, Exception> {
        guard let activity = Activity(action) else {
            return .failure(.init(
                "Failed to synthesize activity.",
                metadata: .init(sender: self)
            ))
        }

        do {
            return try await .success(
                conversation.updateValues(
                    with: [
                        \.activities: ((conversation.activities ?? []) + [activity]).filter { $0 != .empty },
                        \.metadata: newMetadata,
                    ]
                )
            )
        } catch {
            return .failure(error)
        }
    }

    func viewAppeared() {
        uiApplication.resignFirstResponders()
        UISegmentedControl.appearance().apportionsSegmentWidthsByContent = true
    }

    /// `.getChatParticipantsReturned(.success)`
    func viewLoaded() {
        Task.delayed(by: .seconds(1)) { @MainActor [weak self] in
            guard let self else { return }
            uiSegmentBackgroundViews
                .filter { $0.backgroundColor != self.uiSegmentBackgroundViewBackgroundColor }
                .forEach { $0.backgroundColor = self.uiSegmentBackgroundViewBackgroundColor }

            guard uiApplication.isPresentingSheet else { return }
            viewLoaded()
        }
    }

    // MARK: - Clear Cache

    func clearCache() {
        cachedChatParticipantsForUserIDs = nil
    }
}
