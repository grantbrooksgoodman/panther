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

/* 3rd-party */
import AlertKit
import Redux

public final class ChatInfoPageViewService: Cacheable {
    // MARK: - Types

    public enum MetadataChangeType {
        case name(String)
        case removePhoto
        case selectPhotoFromCamera
        case selectPhotoFromLibrary
    }

    // MARK: - Dependencies

    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.clientSession.conversation.currentConversation) private var currentConversation: Conversation?

    // MARK: - Properties

    public var cache: Cache
    public var emptyCache: Cache

    // MARK: - Init

    public init() {
        emptyCache = .init(
            [
                .participantsForEncodedConversationIDs: ["": []],
            ]
        )
        cache = emptyCache
    }

    // MARK: - Get Chat Participants

    /// `.viewAppeared`
    public func getChatParticipants() async -> Callback<[ChatParticipant], Exception> {
        guard let currentConversation else {
            return .failure(.init("No current conversation.", metadata: [self, #file, #function, #line]))
        }

        if let cachedValue = cache.value(forKey: .participantsForEncodedConversationIDs) as? [String: [ChatParticipant]],
           let participants = cachedValue[currentConversation.id.encoded] {
            return .success(participants)
        }

        guard let users = currentConversation.users else {
            if let exception = await self.currentConversation?.setUsers() {
                return .failure(exception)
            }

            return await getChatParticipants()
        }

        var chatParticipants = [ChatParticipant]()

        for user in users {
            let firstCNContactResult = await contactService.firstCNContact(for: user.phoneNumber)

            switch firstCNContactResult {
            case let .success(cnContact):
                let contactPair: ContactPair = .init(
                    contact: .init(cnContact),
                    numberPairs: [.init(phoneNumber: user.phoneNumber, users: [user])]
                )

                chatParticipants.append(
                    .init(
                        displayName: contactPair.contact.fullName,
                        cnContactContainer: .init(cnContact.mutableCopy() as? CNMutableContact),
                        contactPair: contactPair
                    )
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

                chatParticipants.append(
                    .init(
                        displayName: contactPair.contact.fullName,
                        cnContactContainer: .init(cnContact, isUnknown: true),
                        contactPair: contactPair
                    )
                )
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
        let sortedParticipants = sorted(withAlphabeticalPrefix) + sorted(withoutAlphabeticalPrefix)

        if var cachedValue = cache.value(forKey: .participantsForEncodedConversationIDs) as? [String: [ChatParticipant]] {
            cachedValue[currentConversation.id.encoded] = sortedParticipants
            cache.set(cachedValue, forKey: .participantsForEncodedConversationIDs)
        } else {
            cache.set([currentConversation.id.encoded: sortedParticipants], forKey: .participantsForEncodedConversationIDs)
        }

        return .success(sortedParticipants)
    }

    // MARK: - Present Change Metadata Action Sheet

    /// `.changeMetadataButtonTapped`
    public func presentChangeMetadataActionSheet() async -> MetadataChangeType? {
        func presentChangeNameAlert() async -> String? {
            var conversationName = ""
            if let name = currentConversation?.metadata.name,
               !name.isBangQualifiedEmpty {
                conversationName = name
            }

            let alert: AKTextFieldAlert = .init(
                message: "Choose a new name for this conversation:",
                actions: [.init(title: "Done", style: .preferred)],
                textFieldAttributes: [
                    .editingMode: UITextField.ViewMode.always,
                    .sampleText: conversationName,
                ],
                networkDependent: true
            )

            let presentTextFieldAlertResult = await alert.presentTextFieldAlert()
            guard presentTextFieldAlertResult.actionID != -1 else { return nil }
            return presentTextFieldAlertResult.input
        }

        var actions: [AKAction] = [
            .init(title: "Change name", style: .default),
            .init(title: "Change photo", style: .default),
        ]

        if currentConversation?.metadata.imageData != nil {
            actions.append(.init(title: "Remove photo", style: .destructive))
        }

        var actionSheet: AKActionSheet = .init(actions: actions)

        let actionID = await actionSheet.present()
        guard actionID != -1 else { return nil }

        switch actionID {
        case actions[0].identifier:
            if let string = await presentChangeNameAlert() {
                return .name(string)
            }

        case actions[1].identifier:
            actions = [
                .init(title: "Take photo", style: .default),
                .init(title: "Choose photo from library", style: .default),
            ]

            actionSheet = .init(message: "Change photo", actions: actions)

            let actionID = await actionSheet.present()
            guard actionID != -1 else { return nil }

            switch actionID {
            case actions[0].identifier:
                return .selectPhotoFromCamera

            case actions[1].identifier:
                return .selectPhotoFromLibrary

            default: ()
            }

        case actions[2].identifier:
            return .removePhoto

        default: ()
        }

        return nil
    }

    // MARK: - Clear Cache

    public func clearCache() {
        CacheDomain.ChatInfoPageViewServiceCacheDomainKey.allCases.forEach { cache.removeObject(forKey: .chatInfoPageViewService($0)) }
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum ChatInfoPageViewServiceCacheDomainKey: String, CaseIterable, Equatable {
        case participantsForEncodedConversationIDs
    }
}

private extension Cache {
    convenience init(_ objects: [CacheDomain.ChatInfoPageViewServiceCacheDomainKey: Any]) {
        var mappedObjects = [CacheDomain: Any]()
        objects.forEach { object in
            mappedObjects[.chatInfoPageViewService(object.key)] = object.value
        }
        self.init(mappedObjects)
    }

    func set(_ value: Any, forKey key: CacheDomain.ChatInfoPageViewServiceCacheDomainKey) {
        set(value, forKey: .chatInfoPageViewService(key))
    }

    func value(forKey key: CacheDomain.ChatInfoPageViewServiceCacheDomainKey) -> Any? {
        value(forKey: .chatInfoPageViewService(key))
    }
}
