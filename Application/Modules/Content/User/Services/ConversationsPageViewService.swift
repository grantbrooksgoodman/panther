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

    @Dependency(\.commonServices.contact.sync) private var contactSyncService: ContactSyncService
    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.clientSessionService.user) private var userSessionService: UserSessionService

    // MARK: - Methods

    public func viewAppeared() {
        coreUI.setNavigationBarAppearance(backgroundColor: .navigationBarBackground, titleColor: .navigationBarTitle)
        userSessionService.startObservingConversationHashValueChanges()
    }

    public func reloadData() async -> Callback<[Conversation], Exception> {
        if let exception = await contactSyncService.syncContactPairArchive(forceUpdate: true),
           !exception.isEqual(to: .notAuthorizedForContacts) {
            return .failure(exception)
        }

        let setCurrentUserResult = await userSessionService.setCurrentUser()

        switch setCurrentUserResult {
        case let .success(user):
            if let exception = await updatedCurrentUser() {
                return .failure(exception)
            }

            return .success(user.conversations ?? [])

        case let .failure(exception):
            return .failure(exception)
        }
    }

    public func updatedCurrentUser() async -> Exception? {
        if let exception = await userSessionService.currentUser?.setConversations() {
            return exception
        }

        if let exception = await userSessionService.currentUser?.conversations?.visibleForCurrentUser.setUsers() {
            return exception
        }

        return nil
    }
}
