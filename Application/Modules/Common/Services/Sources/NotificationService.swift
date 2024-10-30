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

/* Proprietary */
import AppSubsystem
import Networking

public final class NotificationService {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.urlSession) private var urlSession: URLSession
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter

    // MARK: - Properties

    public private(set) var pushToken: String?

    // MARK: - Set Badge Number

    public func setBadgeNumber(_ badgeNumber: Int) async -> Exception? {
        do {
            try await userNotificationCenter.setBadgeCount(badgeNumber < 0 ? 0 : badgeNumber)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }

    // MARK: - Notify Users of Message

    public func notify(
        _ users: [User],
        of message: Message,
        conversationIDKey: String
    ) async -> Exception? {
        func notify(_ user: User, of message: Message) async -> Exception? {
            let commonParams = ["UserID": user.id]

            guard let currentUser = clientSession.user.currentUser else {
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
            switch message.contentType {
            case .audio:
                body = "🔊 \(Localized(.audioMessage, languageCode: user.languageCode).wrappedValue)"

            case .media:
                if message.imageComponent != nil {
                    body = "🏞️ \(Localized(.image, languageCode: user.languageCode).wrappedValue)"
                } else if message.videoComponent != nil {
                    body = "🎥 \(Localized(.video, languageCode: user.languageCode).wrappedValue)"
                } else {
                    body = "📎 \(Localized(.attachment, languageCode: user.languageCode).wrappedValue)"
                }

            case .text:
                if let translations = message.translations {
                    body = translations.first(where: { $0.languagePair.to == user.languageCode })?.output
                    if body == nil {
                        body = translations.first(where: { $0.languagePair.from == user.languageCode })?.input.value.sanitized
                    }
                }
            }

            let newBadgeNumber = await user.hostedBadgeNumber + 1
            if let exception = await user.updateHostedBadgeNumber(newBadgeNumber) {
                return exception
            }

            for pushToken in pushTokens {
                if let exception = await sendNotification(
                    title: currentUser.phoneNumber.formattedString(),
                    body: body ?? .bangQualifiedEmpty,
                    badgeNumber: newBadgeNumber,
                    pushToken: pushToken,
                    extraParams: [
                        "conversationIDKey": conversationIDKey,
                        "recipientUserID": user.id,
                        "userNumberHash": currentUser.phoneNumber.nationalNumberString.digits.encodedHash,
                    ]
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

    // MARK: - Respond to In-app Notification

    @MainActor
    public func respondToInAppNotification(_ notification: UNNotification) async -> Callback<UNNotificationPresentationOptions, Exception> {
        Logger.log(
            "Received notification.\n\"\(notification.request.content.body)\"",
            domain: .notifications,
            metadata: [self, #file, #function, #line]
        )

        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "No current user – will not respond to notification.",
                metadata: [self, #file, #function, #line]
            ))
        }

        // TODO: Remove backwards compatibility after a few updates.
        if let recipientUserID = notification.request.content.userInfo["recipientUserID"] as? String {
            guard recipientUserID == currentUser.id else {
                return .failure(.init(
                    "Notification not intended for current user – ignoring.",
                    metadata: [self, #file, #function, #line]
                ))
            }
        }

        let toast: Toast = .init(
            .capsule(),
            title: notification.request.content.title.isBlank ? nil : notification.request.content.title,
            message: notification.request.content.body,
            perpetuation: .ephemeral(.seconds(5))
        )

        // TODO: Remove backwards compatibility after a few updates.
        guard let conversationIDKey = notification.request.content.userInfo["conversationIDKey"] as? String else {
            Toast.show(toast)
            return .success([.sound])
        }

        guard let conversationIDKeys = currentUser.conversations?.visibleForCurrentUser.map({ $0.id.key }),
              conversationIDKeys.contains(conversationIDKey) else {
            return .failure(.init(
                "Current user is not participating in the conversation associated with this notification.",
                metadata: [self, #file, #function, #line]
            ))
        }

        guard clientSession.conversation.currentConversation?.id.key != conversationIDKey else { return .success([.sound]) }

        guard let conversation = currentUser.conversations?.first(where: { $0.id.key == conversationIDKey }) else {
            Toast.show(toast)
            return .success([.sound])
        }

        Toast.show(toast) {
            @Navigator var navigationCoordinator: NavigationCoordinator<RootNavigationService>
            guard self.chatPageState.isPresented else {
                return navigationCoordinator.navigate(to: .userContent(.push(.chat(conversation))))
            }

            navigationCoordinator.navigate(to: .userContent(.stack([])))
            self.chatPageState.addEffectUponIsPresented(changedTo: false, id: .deeplinkToOtherChat) {
                navigationCoordinator.navigate(to: .userContent(.push(.chat(conversation))))
            }
        }

        return .success([.sound])
    }

    // MARK: - Set Push Token

    public func setPushToken(_ pushToken: String?) {
        self.pushToken = pushToken
    }

    // MARK: - Auxiliary

    private func generateAccessToken() async -> Callback<String, Exception> {
        guard let url = URL(string: "https://us-central1-jaguar-5d735.cloudfunctions.net/generateAccessToken") else {
            return .failure(.init(
                "Failed to generate URL.",
                metadata: [self, #file, #function, #line]
            ))
        }

        do {
            let dataResult = try await urlSession.data(for: .init(url: url))

            guard let accessToken = String(data: dataResult.0, encoding: .utf8),
                  let urlResponse = dataResult.1 as? HTTPURLResponse,
                  urlResponse.statusCode == 200 else {
                return .failure(.init(
                    "Failed to decode URL response or status did not indicate success.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            return .success(accessToken)
        } catch {
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    private func sendNotification(
        title: String,
        body: String,
        badgeNumber: Int,
        pushToken: String,
        extraParams: [String: String]
    ) async -> Exception? {
        let generateAccessTokenResult = await generateAccessToken()

        switch generateAccessTokenResult {
        case let .success(accessToken):
            guard let url = URL(string: "https://fcm.googleapis.com/v1/projects/jaguar-5d735/messages:send") else {
                return .init(
                    "Failed to generate URL.",
                    metadata: [self, #file, #function, #line]
                )
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let payload: [String: Any] = [
                "message": [
                    "apns": ["payload": ["aps": [
                        "badge": badgeNumber,
                        "mutable-content": 1,
                    ]]],
                    "data": extraParams,
                    "notification": ["body": body, "title": title],
                    "token": pushToken,
                ],
            ]

            do {
                try request.httpBody = JSONSerialization.data(withJSONObject: payload)
                let dataResult = try await urlSession.data(for: request)

                guard let urlResponse = dataResult.1 as? HTTPURLResponse,
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

        case let .failure(exception):
            return exception
        }
    }
}
