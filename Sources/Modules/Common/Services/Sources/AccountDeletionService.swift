//
//  AccountDeletionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public final class AccountDeletionService {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    private var completedUnits: Double = 0
    private var completionPercent: Double = 0 {
        didSet {
            // TODO: Set only label text once AppSubsystem updated.
            let roundedValue = completionPercent.roundedString
            guard let integer = Int(roundedValue),
                  integer <= 100 else { return }

            core.hud.showProgress(
                text: integer == 100 ? nil : "\(Localized(.deletingData).wrappedValue) (\(roundedValue)%)",
                isModal: true
            )
        }
    }

    // MARK: - Delete Account

    public func deleteAccount() async -> Exception? {
        var exceptions = [Exception]()

        guard let currentUserID = User.currentUserID else {
            return .init(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        clientSession.user.stopObservingCurrentUserChanges()
        defer { core.hud.hide() }

        core.ui.addOverlay(
            alpha: 0.5,
            activityIndicator: nil,
            isModal: false
        )

        core.hud.showProgress(
            text: "\(Localized(.deletingData).wrappedValue) (0%)",
            isModal: true
        )

        // Add to deleted users.

        if let exception = await addToDeletedUsers(currentUserID) {
            exceptions.append(exception)
        }

        // Enumerate messages sent by the current user.

        var messageIDsFromCurrentUser = Set<String>()
        let getMessageIDsFromResult = await getMessageIDsFrom(currentUserID)

        switch getMessageIDsFromResult {
        case let .success(messageIDs): messageIDsFromCurrentUser = messageIDs
        case let .failure(exception): exceptions.append(exception)
        }

        // Synchronize conversations.

        if let exception = await clientSession.user.currentUser?.setConversations() {
            exceptions.append(exception)
        }

        let conversations = clientSession.user.currentUser?.conversations ?? []
        let groupChats = conversations.filter { $0.participants.count > 2 }
        let oneToOneChats = conversations.filter { $0.participants.count == 2 }

        let totalUnits = Double(groupChats.count + oneToOneChats.count + messageIDsFromCurrentUser.count)

        // Remove user from existing group chats.

        for groupChat in groupChats {
            if let exception = await removeFromConversation(
                currentUserID,
                conversation: groupChat
            ) {
                exceptions.append(exception)
            }

            incrementProgress(forTotal: totalUnits)
        }

        // Delete 1:1 conversations.

        for oneToOneChat in oneToOneChats {
            if let exception = await clientSession.conversation.deleteConversation(
                oneToOneChat,
                forced: true
            ) {
                exceptions.append(exception)
            }

            incrementProgress(forTotal: totalUnits)
        }

        // Delete all messages sent by current user.

        for messageID in messageIDsFromCurrentUser {
            if let exception = await networking.messageService.deleteMessage(
                id: messageID
            ) {
                exceptions.append(exception)
            }

            incrementProgress(forTotal: totalUnits)
        }

        // Zero-out all open conversation references for the current user.

        do {
            _ = try (await clientSession.user.currentUser?.updateValue(
                [],
                forKey: .conversationIDs
            ))?.get()
        } catch {
            exceptions.append(.init(error, metadata: .init(sender: self)))
        }

        // Validate database integrity.

        try? await Task.sleep(for: .seconds(1))

        if let exception = await networking.integrityService.repairDatabase() {
            exceptions.append(exception)
        }

        // Delete user reference locally and on server.

        clientSession.user.stopObservingCurrentUserChanges()
        completionPercent = 1

        @Persistent(.currentUserID) var persistedCurrentUserID: String?
        persistedCurrentUserID = nil
        _ = clientSession.user.setCurrentUser(nil)

        if let exception = await networking.database.setValue(
            NSNull(),
            forKey: "\(NetworkPath.users.rawValue)/\(currentUserID)"
        ) {
            exceptions.append(exception)
        }

        // If we encountered errors, validate database integrity again.

        if !exceptions.isEmpty {
            if let exception = await networking.integrityService.repairDatabase() {
                exceptions.append(exception)
            }

            clientSession.user.stopObservingCurrentUserChanges()
        }

        return exceptions.compiledException
    }

    // MARK: - Auxiliary

    private func addToDeletedUsers(_ userID: String) async -> Exception? {
        let getValuesResult = await networking.database.getValues(
            at: NetworkPath.deletedUsers.rawValue
        )

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                clientSession.user.startObservingCurrentUserChanges()
                return .Networking.typecastFailed("array", metadata: .init(sender: self))
            }

            array.append(userID)
            array = array.filter { $0 != .bangQualifiedEmpty }.unique

            if let exception = await networking.database.setValue(
                array,
                forKey: NetworkPath.deletedUsers.rawValue
            ) {
                return exception
            }

        case let .failure(exception):
            guard exception.isEqual(to: .Networking.Database.noValueExists) else {
                clientSession.user.startObservingCurrentUserChanges()
                return exception
            }

            if let exception = await networking.database.setValue(
                [userID],
                forKey: NetworkPath.deletedUsers.rawValue
            ) {
                return exception
            }
        }

        return nil
    }

    private func getMessageIDsFrom(_ userID: String) async -> Callback<Set<String>, Exception> {
        let resolveResult = await IntegrityServiceSession.resolve(.returnOnFailure)

        switch resolveResult {
        case let .success(session):
            return .success(Set(
                session
                    .messageData
                    .compactMapValues {
                        ($0 as? [String: Any])?[
                            Message
                                .SerializationKeys
                                .fromAccountID
                                .rawValue
                        ] as? String
                    }
                    .filter { $0.value == userID }
                    .keys
            ))

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func incrementProgress(forTotal total: Double) {
        completedUnits += 1
        completionPercent = completedUnits / max(total, 1)
    }

    private func removeFromConversation(
        _ userID: String,
        conversation: Conversation
    ) async -> Exception? {
        let updateValueResult = await conversation.updateValue(
            conversation.participants.filter { $0.userID != userID },
            forKey: .participants
        )

        switch updateValueResult {
        case let .success(conversation):
            let newMetadata = conversation.metadata.copyWith(
                messageRecipientConsentAcknowledgementData: conversation
                    .metadata
                    .messageRecipientConsentAcknowledgementData
                    .filter { $0.userID != userID },
                penPalsSharingData: conversation
                    .metadata
                    .penPalsSharingData
                    .filter { $0.userID != userID },
                nilRequiresConsentFromInitiator: conversation
                    .metadata
                    .requiresConsentFromInitiator == userID
            )

            let updateValueResult = await conversation.updateValue(
                newMetadata,
                forKey: .metadata
            )

            switch updateValueResult {
            case .success: return nil
            case let .failure(exception): return exception
            }

        case let .failure(exception): return exception
        }
    }
}

private extension Double {
    var roundedString: String {
        String(Darwin.round(self * 100))
            .components(separatedBy: ".")
            .first ?? "0"
    }
}
