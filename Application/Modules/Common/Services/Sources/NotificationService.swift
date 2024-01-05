//
//  NotificationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UserNotifications

/* 3rd-party */
import Redux

public final class NotificationService {
    // MARK: - Dependencies

    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter

    // MARK: - Properties

    public private(set) var pushToken: String?
    @Persistent(.badgeNumber) private var badgeNumber: Int?

    // MARK: - Methods

    public func resetBadgeNumber() async -> Exception? {
        badgeNumber = nil

        do {
            try await userNotificationCenter.setBadgeCount(0)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }

    public func respondToNotification(_ notification: UNNotification) async -> Exception? {
        Logger.log(
            "Received notification.\n\(notification.request.content.body)",
            domain: .notifications,
            metadata: [self, #file, #function, #line]
        )

        let badgeNumber = (badgeNumber ?? 0) + 1
        self.badgeNumber = badgeNumber

        do {
            try await userNotificationCenter.setBadgeCount(badgeNumber)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }

    public func setPushToken(_ pushToken: String?) {
        self.pushToken = pushToken
    }
}
