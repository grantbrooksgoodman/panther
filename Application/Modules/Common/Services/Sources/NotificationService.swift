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
    // MARK: - Dependencies

    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.urlSession) private var urlSession: URLSession
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter
    @Dependency(\.clientSessionService.user) private var userSession: UserSessionService

    // MARK: - Properties

    public private(set) var pushToken: String?

    // MARK: - Badge Number

    public func resetBadgeNumber() async -> Exception? {
        do {
            try await userNotificationCenter.setBadgeCount(0)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }

    public func setBadgeNumber(_ badgeNumber: Int) async -> Exception? {
        do {
            try await userNotificationCenter.setBadgeCount(badgeNumber < 0 ? 0 : badgeNumber)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
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
                    body = message.translations.first(where: { $0.languagePair.from == user.languageCode })?.input.value()
                }
            }

            let incrementBadgeNumberResult = await incrementBadgeNumber(for: user)

            switch incrementBadgeNumberResult {
            case let .success(badgeNumber):
                for pushToken in pushTokens {
                    // TODO: Localize this string.
                    let audioMessageBody = "Audio Message" // Localized(.audioMessage).wrappedValue

                    if let exception = await sendNotification(
                        title: currentUser.phoneNumber.formattedString(),
                        body: body ?? "🔊 \(audioMessageBody)",
                        badgeNumber: badgeNumber,
                        pushToken: pushToken,
                        extraParams: ["userNumberHash": currentUser.phoneNumber.nationalNumberString.digits.compressedHash]
                    ) {
                        return exception.appending(extraParams: commonParams)
                    }
                }

            case let .failure(exception):
                return exception.appending(extraParams: commonParams)
            }

            return nil
        }

        for user in users {
            if let exception = await notify(user, of: message),
               !exception.isEqual(to: .notRegisteredForPushNotifications) {
                return exception
            }
        }

        return nil
    }

    // MARK: - Respond to Notification

    public func respondToNotification(_ notification: UNNotification) async -> Callback<UNNotificationPresentationOptions, Exception> {
        Logger.log(
            "Received notification.\n\"\(notification.request.content.body)\"",
            domain: .notifications,
            metadata: [self, #file, #function, #line]
        )

        var badgeNumber = (userSession.currentUser?.badgeNumber ?? 0) + 1
        if let notificationBadgeNumber = notification.request.content.badge as? Int {
            badgeNumber = notificationBadgeNumber
        }

        if let exception = await setBadgeNumber(badgeNumber) {
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

    private func incrementBadgeNumber(for user: User) async -> Callback<Int, Exception> {
        let keyPath = "\(networking.config.paths.users)/\(user.id)/\(User.SerializationKey.badgeNumber.rawValue)"
        let getValuesResult = await networking.database.getValues(at: keyPath)

        switch getValuesResult {
        case let .success(values):
            guard let integer = values as? Int else {
                return .failure(.init(
                    "Failed to typecast values to integer.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            let updateValueResult = await user.updateValue(integer + 1, forKey: .badgeNumber)

            switch updateValueResult {
            case let .success(user):
                return .success(user.badgeNumber)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func sendNotification(
        title: String,
        body: String,
        badgeNumber: Int,
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
                badgeNumber: badgeNumber,
                pushToken: pushToken,
                extraParams: extraParams
            )
        }

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
        payload["notification"] = [
            "badge": badgeNumber,
            "body": body,
            "title": title,
        ] as [String: Any]
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
