//
//  NotificationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit
import UserNotifications

/* 3rd-party */
import Redux

public final class NotificationService {
    // MARK: - Types

    public enum BadgeNumberMutation {
        case decrement(by: Int = 1)
        case increment(by: Int = 1)
        case set(to: Int)
    }

    // MARK: - Dependencies

    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.urlSession) private var urlSession: URLSession
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    public private(set) var pushToken: String?

    // MARK: - Modify Badge Number

    public func modifyBadgeNumber(_ mutation: BadgeNumberMutation) async -> Exception? {
        func setBadgeNumber(_ badgeNumber: Int) async -> Exception? {
            do {
                try await userNotificationCenter.setBadgeCount(badgeNumber < 0 ? 0 : badgeNumber)
            } catch {
                return .init(error, metadata: [self, #file, #function, #line])
            }

            return nil
        }

        switch mutation {
        case let .decrement(by: value):
            return await setBadgeNumber(await uiApplication.applicationIconBadgeNumber - value)

        case let .increment(by: value):
            return await setBadgeNumber(await uiApplication.applicationIconBadgeNumber + value)

        case let .set(to: value):
            return await setBadgeNumber(value)
        }
    }

    // MARK: - Notify Users of Message

    public func notify(_ users: [User], of message: Message) async -> Exception? {
        func notify(_ user: User, of message: Message) async -> Exception? {
            let commonParams = ["UserID": user.id]

            guard let currentUser = userSession.currentUser else {
                return .init(
                    "Current user has not been set.",
                    metadata: [self, #file, #function, #line]
                ).appending(extraParams: commonParams)
            }

            guard let pushTokens = user.pushTokens else {
                return .init(
                    "The specified user has not registered for push notifications.",
                    metadata: [self, #file, #function, #line]
                ).appending(extraParams: commonParams)
            }

            var body: String?
            if !message.hasAudioComponent {
                body = message.translations.first(where: { $0.languagePair.to == user.languageCode })?.output
                if body == nil {
                    body = message.translations.first(where: { $0.languagePair.from == user.languageCode })?.input.value().sanitized
                }
            }

            for pushToken in pushTokens {
                if let exception = await sendNotification(
                    title: currentUser.phoneNumber.formattedString(),
                    body: body ?? "🔊 \(Localized(.audioMessage, languageCode: user.languageCode).wrappedValue)",
                    pushToken: pushToken,
                    extraParams: ["userNumberHash": currentUser.phoneNumber.nationalNumberString.digits.encodedHash]
                ) {
                    return exception.appending(extraParams: commonParams)
                }
            }

            return nil
        }

        var exceptions = [Exception]()
        for user in users {
            if let exception = await notify(user, of: message),
               !exception.isEqual(to: .notRegisteredForPushNotifications) {
                exceptions.append(exception)
            }
        }

        return exceptions.compiledException
    }

    // MARK: - Respond to Notification

    public func respondToNotification(_ notification: UNNotification) async -> Callback<UNNotificationPresentationOptions, Exception> {
        Logger.log(
            "Received notification.\n\"\(notification.request.content.body)\"",
            domain: .notifications,
            metadata: [self, #file, #function, #line]
        )

        if let exception = await modifyBadgeNumber(.increment()) {
            return .failure(exception)
        }

        switch await uiApplication.applicationState {
        case .active:
            Observables.rootViewToast.value = .init(
                .capsule(),
                title: notification.request.content.title.isBlank ? nil : notification.request.content.title,
                message: notification.request.content.body,
                perpetuation: .ephemeral(.seconds(5))
            )

            return .success([])

        case .background,
             .inactive:
            return .success([.badge, .banner, .list, .sound])

        @unknown default:
            return .success([.badge, .banner, .list, .sound])
        }
    }

    // MARK: - Set Push Token

    public func setPushToken(_ pushToken: String?) {
        self.pushToken = pushToken
    }

    // MARK: - Auxiliary

    private func sendNotification(
        title: String,
        body: String,
        pushToken: String,
        extraParams: [String: String]
    ) async -> Exception? {
        guard let pushAPIKey = metadataService.pushAPIKey else {
            if let exception = await metadataService.resolveValues() {
                return exception
            }

            return await sendNotification(
                title: title,
                body: body,
                pushToken: pushToken,
                extraParams: extraParams
            )
        }

        // TODO: This needs to change to use an OAuth 2.0 credential by June 20th. Notifications will stop working.

        guard let url = URL(string: "https://fcm.googleapis.com/fcm/send") else {
            return .init(
                "Failed to generate URL.",
                metadata: [self, #file, #function, #line]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue("key=\(pushAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = ["mutable_content": true, "to": pushToken]
        payload["notification"] = ["body": body, "title": title]
        payload["data"] = extraParams

        do {
            try request.httpBody = JSONSerialization.data(withJSONObject: payload)
            let dataResult = try await urlSession.data(for: request)

            guard let responseString = String(data: dataResult.0, encoding: .utf8),
                  responseString.contains("\"success\":1"),
                  let urlResponse = dataResult.1 as? HTTPURLResponse,
                  urlResponse.statusCode == 200 else {
                return .init(
                    "Failed to decode URL response or status did not indicate success.",
                    metadata: [self, #file, #function, #line]
                )
            }

            return nil
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }
}
