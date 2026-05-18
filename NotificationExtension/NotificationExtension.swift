//
//  NotificationExtension.swift
//  NotificationExtension
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import UserNotifications

final class NotificationExtension: UNNotificationServiceExtension {
    // MARK: - Properties

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let appGroupDefaults = UserDefaults(suiteName: NotificationExtensionConstants.appGroupDefaultsSuiteName)
    private let jsonDecoder = JSONDecoder()

    // MARK: - Methods

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent,
              let appGroupDefaults else { return contentHandler(request.content) }

        func setSubtitleAndComplete() { // swiftlint:disable:next line_length
            guard let encodedConversationNameMapData = appGroupDefaults.value(
                forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName
            ) as? Data,
                let conversationNameMapDictionary = try? jsonDecoder.decode(
                    [String: String].self,
                    from: encodedConversationNameMapData
                ),
                let conversationIDKey = bestAttemptContent.userInfo[
                    NotificationExtensionConstants.conversationIDKeyUserInfoKey
                ] as? String,
                let conversationName = conversationNameMapDictionary[
                    conversationIDKey
                ] else { return contentHandler(bestAttemptContent) }

            bestAttemptContent.subtitle = conversationName
            contentHandler(bestAttemptContent)
        }

        defer { setSubtitleAndComplete() }
        guard let encodedContactArchiveData = appGroupDefaults.value(
            forKey: NotificationExtensionConstants.contactArchiveDefaultsKeyName
        ) as? Data,
            let contactArchiveDictionary = try? jsonDecoder.decode(
                [[String]: String].self,
                from: encodedContactArchiveData
            ),
            let userNumberHash = bestAttemptContent.userInfo[
                NotificationExtensionConstants.userNumberHashUserInfoKey
            ] as? String,
            let matchingContactKey = contactArchiveDictionary.keys.first(where: {
                $0.contains(userNumberHash)
            }),
            let fullName = contactArchiveDictionary[
                matchingContactKey
            ] else { return }

        if let isReaction = bestAttemptContent.userInfo[
            NotificationExtensionConstants.isReactionUserInfoKey
        ] as? String, isReaction == "true" {
            if let reactionSuffix = bestAttemptContent.userInfo[
                NotificationExtensionConstants.reactionSuffixUserInfoKey
            ] as? String, !reactionSuffix.isEmpty {
                bestAttemptContent.title = "\(fullName) \(reactionSuffix)"
            }
        } else {
            bestAttemptContent.title = fullName
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        guard let contentHandler,
              let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }
}
