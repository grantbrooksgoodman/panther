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

struct NotificationService {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.urlSession) private var urlSession: URLSession
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter

    // MARK: - Set Badge Number

    func setBadgeNumber(
        _ badgeNumber: Int,
        updateHostedValue: Bool = true
    ) async throws(Exception) {
        do {
            try await userNotificationCenter.setBadgeCount(
                badgeNumber < 0 ? 0 : badgeNumber
            )
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        guard updateHostedValue,
              let currentUser = clientSession.user.currentUser else { return }
        try await updateHostedBadgeNumber(
            badgeNumber < 0 ? 0 : badgeNumber,
            user: currentUser
        )
    }

    // MARK: - Notify Users of Message

    func notify(
        _ users: [User],
        ofReaction reaction: Reaction? = nil,
        message: Message,
        conversationIDKey: String,
        isPenPalsConversation: Bool
    ) async throws(Exception) {
        guard let currentUser = clientSession.user.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        let currentUserFormattedPhoneNumberString = currentUser.phoneNumber.formattedString()
        guard let reaction else {
            try await users.map {
                do throws(Exception) {
                    try await self.notify(
                        $0,
                        title: isPenPalsConversation ? self.penPalsName(for: $0) : currentUserFormattedPhoneNumberString,
                        body: self.notificationBody(
                            for: message,
                            user: $0
                        ),
                        conversationIDKey: conversationIDKey,
                        isReaction: false
                    )
                } catch {
                    guard !error.isEqual(
                        to: .notRegisteredForPushNotifications
                    ) else { return }
                    throw error
                }
            }
            return
        }

        try await users.map {
            let reactedString = Localized(
                .reacted,
                languageCode: $0.languageCode
            ).wrappedValue
            let reactionSuffix = "\(reactedString) \(reaction.style.emojiValue)"

            let titlePrefix = isPenPalsConversation ? penPalsName(for: $0) : currentUserFormattedPhoneNumberString
            var body = notificationBody(
                for: message,
                user: $0
            )

            if let resolvedBody = body,
               message.contentType == .text {
                body = "“\(resolvedBody)”"
            }

            do throws(Exception) {
                try await self.notify(
                    $0,
                    title: "\(titlePrefix) \(reactionSuffix)",
                    body: body,
                    conversationIDKey: conversationIDKey,
                    isReaction: true,
                    reactionSuffix: reactionSuffix
                )
            } catch {
                guard !error.isEqual(
                    to: .notRegisteredForPushNotifications
                ) else { return }
                throw error
            }
        }
    }

    // MARK: - Notify of Prevarication Mode Analytics Event

    func notifyOfPrevaricationModeAnalyticsEvent(
        _ title: String,
        body: String
    ) async throws(Exception) {
        let userData: [String: Any] = try await networking.database.getValues(
            at: "\(NetworkEnvironment.staging.shortString)/\(NetworkPath.users.rawValue)"
        )

        let pushTokens = userData.reduce(into: [String]()) { partialResult, keyPair in
            if let userData = keyPair.value as? [String: Any],
               let pushTokens = userData[
                   User.SerializableKey.pushTokens.rawValue
               ] as? [String],
               !pushTokens.isBangQualifiedEmpty {
                partialResult.append(contentsOf: pushTokens)
            }
        }

        try await pushTokens.unique.map(
            failFast: false
        ) {
            try await sendNotification(
                title: title,
                body: body,
                badgeNumber: 0,
                pushToken: $0,
                userInfo: [:],
                isReaction: false
            )
        }
    }

    // MARK: - Respond to In-app Notification

    @MainActor
    func respondToInAppNotification(
        _ notification: UNNotification
    ) async throws(Exception) -> UNNotificationPresentationOptions {
        let notificationContent = notification.request.content
        Logger.log(
            "Received notification.\n\"\(notificationContent.body)\"",
            domain: .notifications,
            sender: self
        )

        guard let currentUser = clientSession.user.currentUser else {
            throw Exception(
                "No current user – will not respond to notification.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        guard let conversationIDKey = notificationContent.userInfo["conversationIDKey"] as? String,
              let isReactionString = notificationContent.userInfo["isReaction"] as? String,
              let recipientUserID = notificationContent.userInfo["recipientUserID"] as? String else {
            throw Exception(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        guard recipientUserID == currentUser.id else {
            throw Exception(
                "Notification not intended for current user – ignoring.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        guard let conversation = clientSession
            .store
            .getConversation(idKey: conversationIDKey),
            conversation.isVisibleForCurrentUser else {
            throw Exception(
                "Conversation associated with this notification is not visible to the current user.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        guard !(
            chatPageState.isPresented && clientSession
                .conversation
                .currentConversation?
                .id
                .key == conversationIDKey
        ) else {
            guard isReactionString == "true" else { return [] }
            services.haptics.generateFeedback(.medium)
            return []
        }

        let toast: Toast = .init(
            .capsule(),
            title: notificationContent.title.isBlank ? nil : notificationContent.title,
            message: notificationContent.body,
            perpetuation: .ephemeral(.seconds(5))
        )

        Toast.show(toast) {
            Task { @MainActor in
                @Dependency(\.navigation) var navigation: Navigation
                guard chatPageState.isPresented else {
                    navigation.navigate(to: .userContent(.push(.chat(conversation))))
                    return
                }

                navigation.navigate(to: .userContent(.stack([])))
                chatPageState.addEffectUponIsPresented(
                    changedTo: false,
                    id: .deeplinkToOtherChat
                ) {
                    Task { @MainActor in
                        Application.dismissSheets()
                        navigation.navigate(to: .userContent(.push(.chat(conversation))))
                    }
                }
            }
        }

        return [.sound]
    }

    // MARK: - Auxiliary

    private func generateAccessToken() async throws(Exception) -> String {
        guard let url = URL(string: "https://us-central1-jaguar-5d735.cloudfunctions.net/generateAccessToken") else {
            throw Exception(
                "Failed to generate URL.",
                metadata: .init(sender: self)
            )
        }

        do {
            let dataResult = try await urlSession.data(for: .init(url: url))

            guard let accessToken = String(data: dataResult.0, encoding: .utf8),
                  let urlResponse = dataResult.1 as? HTTPURLResponse,
                  (200 ..< 300).contains(urlResponse.statusCode) else {
                throw Exception(
                    "Failed to decode URL response or status did not indicate success.",
                    userInfo: [
                        "ResponseBody": String(
                            data: dataResult.0,
                            encoding: .utf8
                        ) ?? "<non-utf8>",
                        "URLResponseCode": (dataResult.1 as? HTTPURLResponse)?.statusCode ?? -1,
                    ],
                    metadata: .init(sender: self)
                )
            }

            return accessToken
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func notificationBody(
        for message: Message,
        user: User
    ) -> String? {
        var body: String?

        switch message.contentType {
        case .audio:
            body = "🔊 \(Localized(.audioMessage, languageCode: user.languageCode).wrappedValue)"

        case .media:
            if message.documentComponent != nil {
                body = "📄 \(Localized(.document, languageCode: user.languageCode).wrappedValue)"
            } else if message.imageComponent != nil {
                body = "🏞️ \(Localized(.image, languageCode: user.languageCode).wrappedValue)"
            } else if message.videoComponent != nil {
                body = "🎥 \(Localized(.video, languageCode: user.languageCode).wrappedValue)"
            } else {
                body = "📎 \(Localized(.attachment, languageCode: user.languageCode).wrappedValue)"
            }

        case .text:
            guard !message.isConsentMessage else {
                return Localized(
                    message.isConsentAcknowledgementMessage ? .messageRecipientConsentAcknowledgementMessage : .messageRecipientConsentRequestMessage,
                    languageCode: user.languageCode
                ).wrappedValue.sanitized.trimmingBorderedWhitespace
            }

            if let translations = message.translations {
                body = (
                    translations
                        .first(where: {
                            $0.languagePair.to == user.languageCode
                        })?
                        .output ?? translations
                        .first(where: {
                            $0.languagePair.from == user.languageCode
                        })?
                        .input
                        .value
                )?.sanitized
            }
        }

        return body
    }

    private func notify(
        _ user: User,
        title: String,
        body: String?,
        conversationIDKey: String,
        isReaction: Bool,
        reactionSuffix: String? = nil
    ) async throws(Exception) {
        let userInfo = ["UserID": user.id]

        guard let currentUser = clientSession.user.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        let newBadgeNumber = await user.hostedBadgeNumber + 1
        try await updateHostedBadgeNumber(
            newBadgeNumber,
            user: user
        )

        guard let pushTokens = user.pushTokens else {
            throw Exception(
                "The specified user has not registered for push notifications.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        let userNumberHash = currentUser.phoneNumber.nationalNumberString.digits.encodedHash
        var exceptions = [Exception]()
        for pushToken in pushTokens {
            do {
                try await sendNotification(
                    title: title,
                    body: body ?? .bangQualifiedEmpty,
                    badgeNumber: newBadgeNumber,
                    pushToken: pushToken,
                    userInfo: [
                        "conversationIDKey": conversationIDKey,
                        "isReaction": isReaction ? "true" : "false",
                        "reactionSuffix": reactionSuffix ?? "",
                        "recipientUserID": user.id,
                        "userNumberHash": userNumberHash,
                    ],
                    isReaction: isReaction
                )
            } catch {
                if error.isEqual(to: .stalePushToken) {
                    do {
                        try await services
                            .pushToken
                            .eraseStalePushToken(pushToken)
                    } catch {
                        exceptions.append(error)
                    }
                } else {
                    exceptions.append(error)
                }
            }
        }

        if let exception = exceptions
            .compiledException?
            .appending(userInfo: userInfo) {
            throw exception
        }
    }

    private func penPalsName(for otherUser: User) -> String {
        guard let currentUser = clientSession.user.currentUser else { return "PenPal" }
        let localizedRegionName = services.regionDetail.localizedRegionName(
            regionCode: currentUser.phoneNumber.regionCode,
            languageCode: otherUser.languageCode
        )
        return otherUser.languageCode == "en" ? "PenPal from \(localizedRegionName)" : "PenPal (\(localizedRegionName))"
    }

    // swiftlint:disable:next function_parameter_count
    private func sendNotification(
        title: String,
        body: String,
        badgeNumber: Int,
        pushToken: String,
        userInfo: [String: String],
        isReaction: Bool
    ) async throws(Exception) {
        guard let url = URL(
            string: "https://fcm.googleapis.com/v1/projects/jaguar-5d735/messages:send"
        ) else {
            throw Exception(
                "Failed to generate URL.",
                metadata: .init(sender: self)
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        try await request.setValue(
            "Bearer \(generateAccessToken())",
            forHTTPHeaderField: "Authorization"
        )

        var notificationParameters = ["title": title]
        if !body.isBangQualifiedEmpty { notificationParameters["body"] = body }

        let payload: [String: Any] = [
            "message": [
                "apns": [
                    "payload": [
                        "aps": [
                            "badge": badgeNumber,
                            "mutable-content": 1,
                            "sound": isReaction ? "Reaction.caf" : "default",
                        ],
                    ],
                ],
                "data": userInfo,
                "notification": notificationParameters,
                "token": pushToken,
            ],
        ]

        do {
            try request.httpBody = JSONSerialization.data(withJSONObject: payload)
            let dataResult = try await urlSession.data(for: request)

            guard let urlResponse = dataResult.1 as? HTTPURLResponse,
                  (200 ..< 300).contains(urlResponse.statusCode) else {
                let responseBody = String(
                    data: dataResult.0,
                    encoding: .utf8
                ) ?? "<non-utf8>"
                let responseCode = (dataResult.1 as? HTTPURLResponse)?.statusCode ?? -1

                if responseBody.contains("UNREGISTERED"),
                   responseCode == 404 {
                    throw Exception(
                        "The provided push token is stale.",
                        isReportable: false,
                        userInfo: ["PushToken": pushToken],
                        metadata: .init(sender: self)
                    )
                }

                throw Exception(
                    "Failed to decode URL response or status did not indicate success.",
                    isReportable: !responseBody.contains("UNREGISTERED"),
                    userInfo: [
                        "ResponseBody": responseBody,
                        "URLResponseCode": responseCode,
                    ],
                    metadata: .init(sender: self)
                )
            }
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func updateHostedBadgeNumber(
        _ badgeNumber: Int? = nil,
        user: User
    ) async throws(Exception) {
        switch user.id == User.currentUserID {
        case true:
            var newBadgeNumber = badgeNumber
            if newBadgeNumber == nil {
                newBadgeNumber = user.calculateBadgeNumber()
            }

            guard let newBadgeNumber else {
                throw Exception(
                    "Failed to resolve badge number.",
                    metadata: .init(sender: self)
                )
            }

            try await networking.database.setValue(
                newBadgeNumber < 0 ? 0 : newBadgeNumber,
                forKey: [
                    NetworkPath.users.rawValue,
                    user.id,
                    User.SerializableKey.badgeNumber.rawValue,
                ].joined(separator: "/")
            )

        case false:
            guard let badgeNumber else {
                throw Exception(
                    "Must supply badge number for users other than current user.",
                    metadata: .init(sender: self)
                )
            }

            try await networking.database.setValue(
                badgeNumber < 0 ? 0 : badgeNumber,
                forKey: [
                    NetworkPath.users.rawValue,
                    user.id,
                    User.SerializableKey.badgeNumber.rawValue,
                ].joined(separator: "/")
            )
        }
    }
}

// swiftlint:enable file_length type_body_length
