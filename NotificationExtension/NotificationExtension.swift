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

        guard let bestAttemptContent,
              let appGroupDefaults else { return contentHandler(request.content) }

        func setSubtitleAndComplete() { // swiftlint:disable:next line_length
            guard let encodedConversationNameMapData = appGroupDefaults.value(forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName) as? Data,
                  let conversationNameMapDictionary = try? jsonDecoder.decode([String: String].self, from: encodedConversationNameMapData),
                  let conversationIDKey = bestAttemptContent.userInfo[NotificationExtensionConstants.conversationIDKeyUserInfoKey] as? String,
                  let conversationName = conversationNameMapDictionary[conversationIDKey] else {
                return contentHandler(bestAttemptContent)
            }

            bestAttemptContent.subtitle = conversationName
            contentHandler(bestAttemptContent)
        }

        guard let encodedContactArchiveData = appGroupDefaults.value(forKey: NotificationExtensionConstants.contactArchiveDefaultsKeyName) as? Data,
              let contactArchiveDictionary = try? jsonDecoder.decode([[String]: String].self, from: encodedContactArchiveData),
              let userNumberHash = bestAttemptContent.userInfo[NotificationExtensionConstants.userNumberHashUserInfoKey] as? String,
              let matchingContactKey = contactArchiveDictionary.keys.first(where: { $0.contains(userNumberHash) }),
              let fullName = contactArchiveDictionary[matchingContactKey] else { return setSubtitleAndComplete() }

        if let isReaction = bestAttemptContent.userInfo[NotificationExtensionConstants.isReactionUserInfoKey] as? String,
           isReaction == "true" {
            guard let lastNumber = bestAttemptContent.title.last(where: { $0.isNumber }),
                  let suffix = bestAttemptContent
                  .title
                  .components(separatedBy: "\(lastNumber)")
                  .last else {
                guard let firstLetter = bestAttemptContent.title.first(where: { $0.isLetter }),
                      let suffix = bestAttemptContent.title.components(separatedBy: " \(firstLetter)").last else { return setSubtitleAndComplete() }
                bestAttemptContent.title = "\(fullName) \(firstLetter)\(suffix)"
                return setSubtitleAndComplete()
            }

            bestAttemptContent.title = "\(fullName)\(suffix)"
            setSubtitleAndComplete()
        } else {
            bestAttemptContent.title = fullName
            setSubtitleAndComplete()
        }
    }

    override public func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        guard let contentHandler,
              let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }
}
