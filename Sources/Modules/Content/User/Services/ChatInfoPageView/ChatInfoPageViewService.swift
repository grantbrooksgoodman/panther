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

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.quickViewer) private var quickViewer: QuickViewer
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var isPreviewingMedia = false

    @Cached(CacheKey.chatParticipantsForUserIDs) private var cachedChatParticipantsForUserIDs: [String: ChatParticipant]?

    // MARK: - Computed Properties

    private var uiSegmentBackgroundViewBackgroundColor: UIColor {
        if UIApplication.v26FeaturesEnabled ||
            Application.isInPrevaricationMode && UIApplication.isFullyV26Compatible {
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
    public func getChatParticipants() async -> Callback<[ChatParticipant], Exception> {
        @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?

        guard let conversation else {
            return .failure(.init("No current conversation.", metadata: .init(sender: self)))
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

    // MARK: - Reducer Action Handlers

    public func mediaItemViewTapped(
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

        quickViewer.onDismiss {
            NavigationBar.setAppearance(Application.isInPrevaricationMode ? .appDefault : .default())
            self.isPreviewingMedia = false
        }
    }

    public func traitCollectionChanged() {
        coreGCD.after(.milliseconds(100)) {
            self.uiSegmentBackgroundViews.forEach {
                $0.backgroundColor = self.uiSegmentBackgroundViewBackgroundColor
            }
        }
    }

    public func viewAppeared() {
        uiApplication.resignFirstResponders()
        UISegmentedControl.appearance().apportionsSegmentWidthsByContent = true
    }

    /// `.getChatParticipantsReturned(.success)`
    public func viewLoaded(withSingleCNContactContainer isPresentingSingleUserContactInfo: Bool) {
        defer {
            coreGCD.after(.seconds(1)) {
                self.uiSegmentBackgroundViews.forEach {
                    $0.backgroundColor = self.uiSegmentBackgroundViewBackgroundColor
                }
            }
        }

        guard isPresentingSingleUserContactInfo else { return }
        hideAdditionalNavigationBarIfNeeded()
    }

    // MARK: - Clear Cache

    public func clearCache() {
        cachedChatParticipantsForUserIDs = nil
    }

    // MARK: - Auxiliary

    private func hideAdditionalNavigationBarIfNeeded() {
        guard UIApplication.v26FeaturesEnabled,
              chatPageState.isPresented,
              uiApplication.isPresentingSheet else { return }

        uiApplication
            .presentedViewControllers
            .filter { $0.activePresentationController is UISheetPresentationController }
            .compactMap(\.navigationController)
            .last?
            .isNavigationBarHidden = true

        coreGCD.after(.seconds(1)) { self.hideAdditionalNavigationBarIfNeeded() }
    }
}
