//
//  ModerationSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

// swiftlint:disable:next type_body_length
struct ModerationSessionService {
    // MARK: - Dependencies

    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.penPals) private var penPalsService: PenPalsService
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Content Moderation

    func blockUsers(
        inConversation conversation: Conversation
    ) async throws(Exception) {
        try await moderate(
            .block,
            dataSource: (conversation, nil)
        )
    }

    func reportUsers(
        inConversation conversation: Conversation
    ) async throws(Exception) {
        try await moderate(
            .report,
            dataSource: (conversation, nil)
        )
    }

    func unblockUsers() async throws(Exception) {
        try await moderate(
            .unblock,
            dataSource: (
                nil,
                getBlockedUsers()
            )
        )
    }

    // MARK: - Auxiliary

    private func alertData(
        _ type: ModerationType,
        contactPairs: [ContactPair]
    ) -> (
        actions: [AKAction],
        translationOptionKeys: [AKActionSheet.TranslationOptionKey]
    ) {
        var actions = [AKAction]()
        for contactPair in contactPairs {
            actions.append(
                .init(contactPair.contact.fullName) {
                    Task {
                        guard await confirmModeration(
                            type,
                            title: "⌘\(contactPair.contact.fullName)⌘"
                        ) else { return }
                        do throws(Exception) {
                            try await performModeration(
                                type,
                                userIDs: contactPair.userIDs
                            )

                            coreHUD.showSuccess()
                        } catch {
                            Logger.log(
                                error,
                                with: .toast
                            )
                        }
                    }
                }
            )
        }

        let allUsersAction: AKAction = .init(
            "\(type.rawValue.firstUppercase) All Users",
            style: .destructive
        ) {
            Task {
                guard await confirmModeration(type, title: "All Users") else { return }
                do throws(Exception) {
                    try await performModeration(
                        type,
                        userIDs: contactPairs.userIDs
                    )

                    coreHUD.showSuccess()
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
                }
            }
        }

        guard actions.count > 1 else {
            return (
                actions,
                [.actions([allUsersAction]), .message, .title]
            )
        }

        actions.append(allUsersAction)
        return (
            actions,
            [.actions([allUsersAction]), .message, .title]
        )
    }

    private func blockUsers(
        ids userIDs: [String]
    ) async throws(Exception) {
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        var blockedUserIDs = currentUser.blockedUserIDs ?? .init()
        blockedUserIDs.append(contentsOf: userIDs)
        blockedUserIDs = blockedUserIDs.filter { $0 != .bangQualifiedEmpty }.unique

        _ = try await currentUser.update(
            \.blockedUserIDs,
            to: blockedUserIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : blockedUserIDs
        )
    }

    private func confirmModeration(
        _ type: ModerationType,
        title: String
    ) async -> Bool {
        let defaultTitle = "\(type.rawValue.firstUppercase) \(title)"
        var message = title == "All Users" ? type.allUsersConfirmationMessage : type.singleUserConfirmationMessage
        if type == .unblock { message = defaultTitle }
        return await AKConfirmationAlert(
            title: message == defaultTitle ? nil : defaultTitle,
            message: message,
            cancelButtonTitle: Localized(.cancel).wrappedValue,
            confirmButtonTitle: type.rawValue.firstUppercase,
            confirmButtonStyle: .destructivePreferred
        ).present(translating: [
            .confirmButtonTitle,
            .message,
            .title,
        ])
    }

    private func getBlockedUsers() async throws(Exception) -> [User] {
        guard let currentUserID = User.currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        let path = [
            NetworkPath.users.rawValue,
            currentUserID,
            User.SerializableKey.blockedUserIDs.rawValue,
        ].joined(separator: "/")

        let rawValue: [String: Any] = try await networking.database.getValues(at: path)
        let blockedUserIDs = Array(rawValue.keys)

        return try await networking.userService.getUsers(ids: blockedUserIDs)
    }

    @MainActor
    private func moderate(
        _ type: ModerationType,
        dataSource: (conversation: Conversation?, users: [User]?)
    ) async throws(Exception) {
        guard dataSource.conversation != nil || dataSource.users != nil,
              let users = dataSource.conversation?.users ?? dataSource.users else {
            throw Exception(
                "No data source provided.",
                metadata: .init(sender: self)
            )
        }

        do {
            try await ContactService.syncIfNeeded()
        } catch {
            Logger.log(error)
        }

        var contactPairs = users.map { $0.contactPair ?? .withUser($0) }
        if dataSource.conversation?.metadata.isPenPalsConversation == true || dataSource.users != nil,
           let currentUserConversations = userSession.currentUser?.conversations?.filter({ !($0.currentUserParticipant?.hasDeletedConversation ?? true) }) {
            for user in users where currentUserConversations.contains(where: {
                !$0.userSharesPenPalsDataWithCurrentUser(user) && !penPalsService.isKnownToCurrentUser(user.id)
            }) {
                guard let index = contactPairs.firstIndex(where: { $0.userIDs.contains(user.id) }) else { continue }
                contactPairs[index] = .withUser(user, name: user.penPalsName)
            }
        }

        contactPairs = contactPairs.sorted(by: {
            $0.contact.fullName < $1.contact.fullName
        }).unique

        guard contactPairs.count > 1 || type == .unblock else {
            guard let contactPair = contactPairs.first,
                  await confirmModeration(
                      type,
                      title: "⌘\(contactPair.contact.fullName)⌘"
                  ) else { return }

            try await performModeration(
                type,
                userIDs: contactPair.userIDs
            )

            return coreHUD.showSuccess()
        }

        let alertData = alertData(type, contactPairs: contactPairs)
        await AKActionSheet(
            title: "\(type.rawValue.firstUppercase) Users",
            actions: alertData.actions,
            cancelButtonTitle: Localized(.cancel).wrappedValue
        ).present(translating: alertData.translationOptionKeys)
    }

    private func performModeration(
        _ type: ModerationType,
        userIDs: [String]
    ) async throws(Exception) {
        let userIDs = userIDs.filter { !$0.isBangQualifiedEmpty }
        guard !userIDs.isBangQualifiedEmpty else {
            throw Exception(
                "No user IDs provided.",
                metadata: .init(sender: self)
            )
        }

        switch type {
        case .block:
            try await blockUsers(ids: userIDs)

        case .report:
            try await reportUsers(ids: userIDs)

        case .unblock:
            try await unblockUsers(ids: userIDs)
        }
    }

    private func reportUsers(
        ids userIDs: [String]
    ) async throws(Exception) {
        try await networking.database.runTransaction(
            at: NetworkPath.reportedUsers.rawValue
        ) { currentValue in
            var reportedUserIDs: [String: Int] = if let map = currentValue as? [
                String: Int
            ] {
                map
            } else if let anyMap = currentValue as? [
                String: Any
            ] {
                anyMap.compactMapValues { $0 as? Int }
            } else {
                [:]
            }

            for userID in userIDs {
                reportedUserIDs[userID, default: 0] += 1
            }

            return reportedUserIDs
        }
    }

    private func unblockUsers(
        ids userIDs: [String]
    ) async throws(Exception) {
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        var blockedUserIDs = currentUser.blockedUserIDs ?? .init()
        blockedUserIDs = blockedUserIDs.filter { !userIDs.contains($0) }
        blockedUserIDs = blockedUserIDs.filter { $0 != .bangQualifiedEmpty }.unique

        _ = try await currentUser.update(
            \.blockedUserIDs,
            to: blockedUserIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : blockedUserIDs
        )

        Observables.traitCollectionChanged.trigger()
    }
}
