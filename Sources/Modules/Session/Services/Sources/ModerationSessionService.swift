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

public struct ModerationSessionService {
    // MARK: - Dependencies

    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Content Moderation

    public func blockUsers(inConversation conversation: Conversation) async -> Exception? {
        await moderate(.block, dataSource: (conversation, nil))
    }

    public func reportUsers(inConversation conversation: Conversation) async -> Exception? {
        await moderate(.report, dataSource: (conversation, nil))
    }

    public func unblockUsers() async -> Exception? {
        let getBlockedUsersResult = await getBlockedUsers()

        switch getBlockedUsersResult {
        case let .success(users):
            return await moderate(.unblock, dataSource: (nil, users))

        case let .failure(exception):
            return exception
        }
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
                        guard await confirmModeration(type, title: "⌘\(contactPair.contact.fullName)⌘") else { return }
                        guard let exception = await performModeration(type, userIDs: contactPair.users.map(\.id)) else { return showSuccess(type) }
                        Logger.log(exception, with: .toast())
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
                guard let exception = await performModeration(type, userIDs: contactPairs.users.map(\.id)) else { return showSuccess(type) }
                Logger.log(exception, with: .toast())
            }
        }

        guard actions.count > 1 else { return (actions, [.actions([allUsersAction]), .message, .title]) }
        actions.append(allUsersAction)
        return (actions, [.actions([allUsersAction]), .message, .title])
    }

    private func blockUsers(ids userIDs: [String]) async -> Exception? {
        guard let currentUser = userSession.currentUser else {
            return .init("Current user has not been set.", metadata: [self, #file, #function, #line])
        }

        var blockedUserIDs = currentUser.blockedUserIDs ?? .init()
        blockedUserIDs.append(contentsOf: userIDs)
        blockedUserIDs = blockedUserIDs.filter { $0 != .bangQualifiedEmpty }.unique

        let updateValueResult = await currentUser.updateValue(
            blockedUserIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : blockedUserIDs,
            forKey: .blockedUserIDs
        )

        switch updateValueResult {
        case let .success(user):
            return userSession.setCurrentUser(user)

        case let .failure(exception):
            return exception
        }
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
            confirmButtonTitle: type.rawValue.firstUppercase,
            confirmButtonStyle: .destructivePreferred
        ).present()
    }

    private func getBlockedUsers() async -> Callback<[User], Exception> {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let currentUserID else {
            return .failure(.init("Current user ID has not been set.", metadata: [self, #file, #function, #line]))
        }

        let path = "\(NetworkPath.users.rawValue)/\(currentUserID)/\(User.SerializationKeys.blockedUserIDs.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.Networking.typecastFailed("array", metadata: [self, #file, #function, #line]))
            }

            return await networking.userService.getUsers(ids: array)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getReportedUserIDs() async -> Callback<[String: Int], Exception> {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.reportedUsers.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Int] else {
                return .failure(.Networking.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            return .success(dictionary)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func moderate(
        _ type: ModerationType,
        dataSource: (conversation: Conversation?, users: [User]?)
    ) async -> Exception? {
        guard dataSource.conversation != nil || dataSource.users != nil,
              let users = dataSource.conversation?.users ?? dataSource.users else {
            return .init(
                "No data source provided.",
                metadata: [self, #file, #function, #line]
            )
        }

        var contactPairs = users.map { services.contact.contactPairArchive.getValue(phoneNumber: $0.phoneNumber) ?? .withUser($0) }
        if dataSource.conversation?.metadata.isPenPalsConversation == true || dataSource.users != nil,
           let currentUserConversations = userSession.currentUser?.conversations?.filter({ !($0.currentUserParticipant?.hasDeletedConversation ?? true) }) {
            for user in users where currentUserConversations.contains(where: {
                !$0.userSharesPenPalsDataWithCurrentUser(user) && !services.penPals.isKnownToCurrentUser(user.id)
            }) {
                guard let index = contactPairs.firstIndex(where: { $0.users.contains(user) }) else { continue }
                contactPairs[index] = .withUser(user, name: user.penPalsName)
            }
        }

        contactPairs = contactPairs.sorted(by: { $0.contact.fullName < $1.contact.fullName }).unique
        guard contactPairs.count > 1 || type == .unblock else {
            guard let contactPair = contactPairs.first,
                  await confirmModeration(type, title: "⌘\(contactPair.contact.fullName)⌘") else { return nil }

            guard let exception = await performModeration(type, userIDs: contactPair.users.map(\.id)) else {
                showSuccess(type)
                return nil
            }

            return exception
        }

        let alertData = alertData(type, contactPairs: contactPairs)
        await AKActionSheet(
            title: "\(type.rawValue.firstUppercase) Users",
            actions: alertData.actions,
            cancelButtonTitle: Localized(.cancel).wrappedValue
        ).present(translating: alertData.translationOptionKeys)
        return nil
    }

    private func performModeration(_ type: ModerationType, userIDs: [String]) async -> Exception? {
        let userIDs = userIDs.filter { !$0.isBangQualifiedEmpty }
        guard !userIDs.isBangQualifiedEmpty else {
            return .init(
                "No user IDs provided.",
                metadata: [self, #file, #function, #line]
            )
        }

        defer { Observables.traitCollectionChanged.trigger() }

        switch type {
        case .block:
            guard let exception = await blockUsers(ids: userIDs) else { return nil }
            return exception

        case .report:
            guard let exception = await reportUsers(ids: userIDs) else { return nil }
            return exception

        case .unblock:
            guard let exception = await unblockUsers(ids: userIDs) else { return nil }
            return exception
        }
    }

    private func reportUsers(ids userIDs: [String]) async -> Exception? {
        let getReportedUserIDsResult = await getReportedUserIDs()

        switch getReportedUserIDsResult {
        case var .success(reportedUserIDs):
            for userID in userIDs {
                if let value = reportedUserIDs[userID] {
                    reportedUserIDs[userID] = value + 1
                } else {
                    reportedUserIDs[userID] = 1
                }
            }

            if let exception = await networking.database.setValue(
                reportedUserIDs,
                forKey: NetworkPath.reportedUsers.rawValue
            ) {
                return exception
            }

        case let .failure(exception):
            Logger.log(exception)

            var reportedUserIDs = [String: Int]()
            userIDs.forEach { reportedUserIDs[$0] = 1 }

            if let exception = await networking.database.setValue(
                reportedUserIDs,
                forKey: NetworkPath.reportedUsers.rawValue
            ) {
                return exception
            }
        }

        return nil
    }

    private func showSuccess(_ type: ModerationType) {
        coreHUD.showSuccess()
        guard type == .block || type == .unblock else { return }
        Observables.updatedCurrentUser.trigger()
    }

    private func unblockUsers(ids userIDs: [String]) async -> Exception? {
        guard let currentUser = userSession.currentUser else {
            return .init("Current user has not been set.", metadata: [self, #file, #function, #line])
        }

        var blockedUserIDs = currentUser.blockedUserIDs ?? .init()
        blockedUserIDs = blockedUserIDs.filter { !userIDs.contains($0) }
        blockedUserIDs = blockedUserIDs.filter { $0 != .bangQualifiedEmpty }.unique

        let updateValueResult = await currentUser.updateValue(
            blockedUserIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : blockedUserIDs,
            forKey: .blockedUserIDs
        )

        switch updateValueResult {
        case let .success(user):
            return userSession.setCurrentUser(user)

        case let .failure(exception):
            return exception
        }
    }
}
