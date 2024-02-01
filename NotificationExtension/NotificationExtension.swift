//
//  NotificationExtension.swift
//  NotificationExtension
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import UserNotifications

public final class NotificationExtension: UNNotificationServiceExtension {
    // MARK: - Properties

    public var contentHandler: ((UNNotificationContent) -> Void)?
    public var bestAttemptContent: UNMutableNotificationContent?

    private let appGroupDefaults = UserDefaults(suiteName: NotificationExtensionConstants.appGroupDefaultsSuiteName)
    private let jsonDecoder = JSONDecoder()

    // MARK: - Methods

    override public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else { return }

        guard let appGroupDefaults,
              let encodedData = appGroupDefaults.value(forKey: NotificationExtensionConstants.defaultsKeyName) as? Data,
              let dictionary = try? jsonDecoder.decode([[String]: String].self, from: encodedData),
              let userNumberHash = bestAttemptContent.userInfo[NotificationExtensionConstants.bestAttemptContentUserInfoKey] as? String,
              let matchingKey = dictionary.keys.first(where: { $0.contains(userNumberHash) }),
              let fullName = dictionary[matchingKey] else {
            contentHandler(bestAttemptContent)
            return
        }

        bestAttemptContent.title = fullName
        contentHandler(bestAttemptContent)
    }

    override public func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        guard let contentHandler,
              let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }
}
