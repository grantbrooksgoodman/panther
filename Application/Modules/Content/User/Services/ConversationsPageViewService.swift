//
//  ConversationsPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct ConversationsPageViewService {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSessionService.user) private var userSession: UserSessionService

    // MARK: - Methods

    public func viewAppeared() async -> Exception? {
        coreUI.setNavigationBarAppearance(backgroundColor: .navigationBarBackground, titleColor: .navigationBarTitle)
        userSession.startObservingConversationHashValueChanges()

        await userSession.updatePushTokens()

        let getBadgeNumberResult = await userSession.currentUser?.getBadgeNumber()

        switch getBadgeNumberResult {
        case let .success(badgeNumber):
            if let exception = await services.notification.setBadgeNumber(badgeNumber) {
                return exception
            }

        case let .failure(exception):
            return exception

        case .none:
            return nil
        }

        return nil
    }

    public func reloadData() async -> Callback<[Conversation], Exception> {
        func syncContactPairArchive() async -> Exception? {
            if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: true),
               !exception.isEqual(to: .notAuthorizedForContacts) {
                return exception
            }

            return nil
        }

        let setCurrentUserResult = await userSession.setCurrentUser()

        switch setCurrentUserResult {
        case let .success(user):
            if let exception = await updatedCurrentUser() {
                return .failure(exception)
            }

            if let exception = await syncContactPairArchive() {
                return .failure(exception)
            }

            return .success(user.conversations ?? [])

        case let .failure(exception):
            return .failure(exception)
        }
    }

    public func updatedCurrentUser() async -> Exception? {
        if let exception = await userSession.currentUser?.setConversations() {
            return exception
        }

        if let exception = await userSession.currentUser?.conversations?.visibleForCurrentUser.setUsers() {
            return exception
        }

        return nil
    }
}
