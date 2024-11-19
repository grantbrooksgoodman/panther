//
//  NotificationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation
import UIKit
import UserNotifications

/* Proprietary */
import AppSubsystem
import Networking

public struct NotificationService {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.urlSession) private var urlSession: URLSession
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter

    // MARK: - Set Badge Number

    public func setBadgeNumber(_ badgeNumber: Int, updateHostedValue: Bool = true) async -> Exception? {
        do {
            try await userNotificationCenter.setBadgeCount(badgeNumber < 0 ? 0 : badgeNumber)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        guard updateHostedValue,
              let currentUser = clientSession.user.currentUser else { return nil }
        return await updateHostedBadgeNumber(badgeNumber, user: currentUser)
    }

    // MARK: - Notify Users of Message

    public func notify(
        _ users: [User],
        ofReaction reaction: Reaction? = nil,
        message: Message,
        conversationIDKey: String
    ) async -> Exception? {
        guard let currentUser = clientSession.user.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            )
        }

        guard let reaction else {
            let title = currentUser.phoneNumber.formattedString()
            for user in users {
                let body = notificationBody(for: message, user: user)
                if let exception = await notify(
                    user,
                    title: title,
                    body: body,
                    conversationIDKey: conversationIDKey,
                    isReaction: false
                ) {
                    guard !exception.isEqual(to: .notRegisteredForPushNotifications) else { continue }
                    return exception
                }
            }

            return nil
        }

        for user in users {
            let reactedString = Localized(.reacted, languageCode: user.languageCode).wrappedValue
            let title = "\(currentUser.phoneNumber.formattedString()) \(reactedString) \(reaction.style.emojiValue)"

            var body = notificationBody(for: message, user: user)
            if let resolvedBody = body,
               message.contentType == .text {
                body = "“\(resolvedBody)”"
            }

            if let exception = await notify(
                user,
                title: title,
                body: body,
                conversationIDKey: conversationIDKey,
                isReaction: true
            ) {
                guard !exception.isEqual(to: .notRegisteredForPushNotifications) else { continue }
                return exception
            }
        }

        return nil
    }

    // MARK: - Notify of Prevarication Mode Analytics Event

    public func notifyOfPrevaricationModeAnalyticsEvent(_ title: String, body: String) async -> Exception? {
        let getValuesResult = await networking.database.getValues(
            at: "\(NetworkEnvironment.staging.shortString)/\(NetworkPath.users.rawValue)",
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
            }

            let pushTokens = dictionary.reduce(into: [String]()) { partialResult, keyPair in
                if let userData = keyPair.value as? [String: Any],
                   let pushTokens = userData[User.SerializationKeys.pushTokens.rawValue] as? [String],
                   !pushTokens.isBangQualifiedEmpty {
                    partialResult.append(contentsOf: pushTokens)
                    partialResult = partialResult.unique
                }
            }

            var exceptions = [Exception]()
            for pushToken in pushTokens {
                if let exception = await sendNotification(
                    title: title,
                    body: body,
                    badgeNumber: 0,
                    pushToken: pushToken,
                    extraParams: [:]
                ) {
                    exceptions.append(exception)
                }
            }
            return exceptions.compiledException

        case let .failure(exception):
            return exception
        }
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
                let exception: Exception = .init(
                    "Notification not intended for current user – ignoring.",
                    metadata: [self, #file, #function, #line]
                )

                return .failure(exception)
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

    private func notificationBody(for message: Message, user: User) -> String? {
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

        return body
    }

    private func notify(
        _ user: User,
        title: String,
        body: String?,
        conversationIDKey: String,
        isReaction: Bool
    ) async -> Exception? {
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

        let newBadgeNumber = await user.hostedBadgeNumber + 1
        if let exception = await updateHostedBadgeNumber(newBadgeNumber, user: user) {
            return exception
        }

        let userNumberHash = currentUser.phoneNumber.nationalNumberString.digits.encodedHash
        for pushToken in pushTokens {
            if let exception = await sendNotification(
                title: title,
                body: body ?? .bangQualifiedEmpty,
                badgeNumber: newBadgeNumber,
                pushToken: pushToken,
                extraParams: [
                    "conversationIDKey": conversationIDKey,
                    "isReaction": isReaction ? "true" : "false",
                    "recipientUserID": user.id,
                    "userNumberHash": userNumberHash,
                ]
            ) {
                return exception.appending(extraParams: commonParams)
            }
        }

        return nil
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

            var notificationParameters = ["title": title]
            if !body.isBangQualifiedEmpty { notificationParameters["body"] = body }

            let payload: [String: Any] = [
                "message": [
                    "apns": ["payload": ["aps": [
                        "badge": badgeNumber,
                        "mutable-content": 1,
                    ]]],
                    "data": extraParams,
                    "notification": notificationParameters,
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

    private func updateHostedBadgeNumber(_ badgeNumber: Int? = nil, user: User) async -> Exception? {
        @Persistent(.currentUserID) var currentUserID: String?
        switch user.id == currentUserID {
        case true:
            var newBadgeNumber = badgeNumber
            if newBadgeNumber == nil {
                newBadgeNumber = await user.calculateBadgeNumber()
            }

            guard let newBadgeNumber else {
                return .init(
                    "Failed to resolve badge number.",
                    metadata: [self, #file, #function, #line]
                )
            }

            return await networking.database.setValue(
                newBadgeNumber,
                forKey: "\(NetworkPath.users.rawValue)/\(user.id)/\(User.SerializationKeys.badgeNumber.rawValue)"
            )

        case false:
            guard let badgeNumber else {
                return .init(
                    "Must supply badge number for users other than current user.",
                    metadata: [self, #file, #function, #line]
                )
            }

            return await networking.database.setValue(
                badgeNumber,
                forKey: "\(NetworkPath.users.rawValue)/\(user.id)/\(User.SerializationKeys.badgeNumber.rawValue)"
            )
        }
    }
}

// swiftlint:enable file_length type_body_length
