//
//  ModerationSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import CoreArchitecture

public struct ModerationSessionService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.contact.contactPairArchive) private var contactPairArchive: ContactPairArchiveService
    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Content Moderation

    public func blockUsers(_ users: [User]) async -> Exception? {
        await moderate(.block, users: users)
    }

    public func reportUsers(_ users: [User]) async -> Exception? {
        await moderate(.report, users: users)
    }

    public func unblockUsers() async -> Exception? {
        let getBlockedUsersResult = await getBlockedUsers()

        switch getBlockedUsersResult {
        case let .success(users):
            return await moderate(.unblock, users: users)

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

        let path = "\(networking.config.paths.users)/\(currentUserID)/\(User.SerializationKeys.blockedUserIDs.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.typecastFailed("array", metadata: [self, #file, #function, #line]))
            }

            return await networking.services.user.getUsers(ids: array)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func getReportedUserIDs() async -> Callback<[String: Int], Exception> {
        let getValuesResult = await networking.database.getValues(at: networking.config.paths.reportedUsers)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Int] else {
                return .failure(.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            return .success(dictionary)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func moderate(_ type: ModerationType, users: [User]) async -> Exception? {
        let contactPairs = users
            .map { contactPairArchive.getValue(phoneNumber: $0.phoneNumber) ?? .withUser($0) }
            .sorted(by: { $0.contact.fullName < $1.contact.fullName })

        guard contactPairs.users.count > 1 || type == .unblock else {
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
        defer { Observables.traitCollectionChanged.trigger() }

        switch type {
        case .block:
            guard let exception = await userSession.blockUsers(ids: userIDs) else { return nil }
            return exception

        case .report:
            guard let exception = await reportUsers(ids: userIDs) else { return nil }
            return exception

        case .unblock:
            guard let exception = await userSession.unblockUsers(ids: userIDs) else { return nil }
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
                forKey: networking.config.paths.reportedUsers
            ) {
                return exception
            }

        case let .failure(exception):
            Logger.log(exception)

            var reportedUserIDs = [String: Int]()
            userIDs.forEach { reportedUserIDs[$0] = 1 }

            if let exception = await networking.database.setValue(
                reportedUserIDs,
                forKey: networking.config.paths.reportedUsers
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
}
