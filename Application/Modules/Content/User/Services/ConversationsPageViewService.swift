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
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Methods

    public func viewAppeared() {
        coreUI.setNavigationBarAppearance()
        userSession.startObservingCurrentUserChanges()

        Task {
            if let exception = await userSession.updatePushTokens() {
                Logger.log(exception)
            }
        }
    }

    /// `.pulledToRefresh`
    public func reloadData() async -> Callback<[Conversation], Exception> {
        func syncContactPairArchive() async -> Exception? {
            if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: true),
               !exception.isEqual(toAny: [.mismatchedHashAndCallingCode, .notAuthorizedForContacts]) {
                return exception
            }

            return nil
        }

        let setCurrentUserResult = await userSession.setCurrentUser()

        switch setCurrentUserResult {
        case let .success(user):
            if let exception = await user.setConversations() {
                return .failure(exception)
            }

            if let exception = await user.conversations?.visibleForCurrentUser.setUsers() {
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
}
