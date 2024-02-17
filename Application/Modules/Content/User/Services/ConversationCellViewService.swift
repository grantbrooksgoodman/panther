//
//  ConversationCellViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import Redux

public final class ConversationCellViewService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.notification) private var notificationService: NotificationService
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    public private(set) var badgeDecrementAmount = 0

    // MARK: - Methods

    /// `.deleteConversationButtonTapped`
    /// - Returns: `true` if the user selected the cancel option.
    public func presentDeletionActionSheet(_ title: String) async -> Bool {
        let actionSheet: AKActionSheet = .init(
            title: title,
            message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
            actions: [.init(title: "Delete", style: .destructive)],
            shouldTranslate: [.actions(indices: nil), .message],
            networkDependent: true
        )

        let actionID = await actionSheet.present()
        return actionID == -1
    }

    /// `.chatPageViewAppeared`,
    /// `.updateCurrentUserBadgeNumberReturned(exception)`
    public func setBadgeDecrementAmount(_ badgeDecrementAmount: Int) {
        self.badgeDecrementAmount = badgeDecrementAmount
    }

    /// `.updateReadDateReturned(.success)`
    public func updateCurrentUserBadgeNumber() async -> Exception? {
        guard let currentUser = userSession.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            )
        }

        let decrementResult = (currentUser.badgeNumber - badgeDecrementAmount)
        let newBadgeNumber = decrementResult < 0 ? 0 : decrementResult

        guard newBadgeNumber != currentUser.badgeNumber else {
            return .init(
                "New badge number is equal to current value.",
                metadata: [self, #file, #function, #line]
            )
        }

        let updateValueResult = await currentUser.updateValue(newBadgeNumber, forKey: .badgeNumber)

        switch updateValueResult {
        case .success:
            if let exception = await notificationService.setBadgeNumber(newBadgeNumber) {
                return exception
            }

            return nil

        case let .failure(exception):
            return exception
        }
    }
}
