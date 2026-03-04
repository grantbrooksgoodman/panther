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
    ) async -> Exception? {
        do {
            try await userNotificationCenter.setBadgeCount(
                badgeNumber < 0 ? 0 : badgeNumber
            )
        } catch {
            return .init(
                error,
                metadata: .init(sender: self)
            )
        }

        guard updateHostedValue,
              let currentUser = clientSession.user.currentUser else { return nil }
        return await updateHostedBadgeNumber(
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
    ) async -> Exception? {
        guard let currentUser = clientSession.user.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        let currentUserFormattedPhoneNumberString = currentUser.phoneNumber.formattedString()
        guard let reaction else {
            for user in users {
                let title = isPenPalsConversation ? penPalsName(for: user) : currentUserFormattedPhoneNumberString
                let body = notificationBody(for: message, user: user)
                if let exception = await notify(
                    user,
                    title: title,
                    body: body,
                    conversationIDKey: conversationIDKey,
                    isReaction: false
                ) {
                    guard !exception.isEqual(
                        to: .notRegisteredForPushNotifications
                    ) else { continue }
                    return exception
                }
            }

            return nil
        }

        for user in users {
            let reactedString = Localized(
                .reacted,
                languageCode: user.languageCode
            ).wrappedValue
            let titlePrefix = isPenPalsConversation ? penPalsName(for: user) : currentUserFormattedPhoneNumberString
            let title = "\(titlePrefix) \(reactedString) \(reaction.style.emojiValue)"

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
                guard !exception.isEqual(
                    to: .notRegisteredForPushNotifications
                ) else { continue }
                return exception
            }
        }

        return nil
    }

    // MARK: - Notify of Prevarication Mode Analytics Event

    func notifyOfPrevaricationModeAnalyticsEvent(
        _ title: String,
        body: String
    ) async -> Exception? {
        let getValuesResult = await networking.database.getValues(
            at: "\(NetworkEnvironment.staging.shortString)/\(NetworkPath.users.rawValue)",
            prependingEnvironment: false
        )

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
            }

            let pushTokens = dictionary.reduce(into: [String]()) { partialResult, keyPair in
                if let userData = keyPair.value as? [String: Any],
                   let pushTokens = userData[
                       User.SerializationKeys.pushTokens.rawValue
                   ] as? [String],
                   !pushTokens.isBangQualifiedEmpty {
                    partialResult.append(contentsOf: pushTokens)
                }
            }

            var exceptions = [Exception]()
            for pushToken in pushTokens.unique {
                if let exception = await sendNotification(
                    title: title,
                    body: body,
                    badgeNumber: 0,
                    pushToken: pushToken,
                    userInfo: [:],
                    isReaction: false
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
    func respondToInAppNotification(_ notification: UNNotification) async -> Callback<UNNotificationPresentationOptions, Exception> {
        let notificationContent = notification.request.content
        Logger.log(
            "Received notification.\n\"\(notificationContent.body)\"",
            domain: .notifications,
            sender: self
        )

        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "No current user – will not respond to notification.",
                isReportable: false,
                metadata: .init(sender: self)
            ))
        }

        guard let conversationIDKey = notificationContent.userInfo["conversationIDKey"] as? String,
              let isReactionString = notificationContent.userInfo["isReaction"] as? String,
              let recipientUserID = notificationContent.userInfo["recipientUserID"] as? String else {
            return .failure(.init(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            ))
        }

        guard recipientUserID == currentUser.id else {
            return .failure(.init(
                "Notification not intended for current user – ignoring.",
                isReportable: false,
                metadata: .init(sender: self)
            ))
        }

        guard let conversation = networking
            .conversationService
            .archive
            .getValue(idKey: conversationIDKey),
            conversation.isVisibleForCurrentUser else {
            return .failure(.init(
                "Conversation associated with this notification is not visible to the current user.",
                isReportable: false,
                metadata: .init(sender: self)
            ))
        }

        guard !(
            chatPageState.isPresented && clientSession
                .conversation
                .currentConversation?
                .id
                .key == conversationIDKey
        ) else {
            guard isReactionString == "true" else { return .success([]) }
            services.haptics.generateFeedback(.medium)
            return .success([])
        }

        let toast: Toast = .init(
            .capsule(),
            title: notificationContent.title.isBlank ? nil : notificationContent.title,
            message: notificationContent.body,
            perpetuation: .ephemeral(.seconds(5))
        )

        Toast.show(toast) {
            @Dependency(\.navigation) var navigation: Navigation
            guard self.chatPageState.isPresented else {
                return navigation.navigate(to: .userContent(.push(.chat(conversation))))
            }

            navigation.navigate(to: .userContent(.stack([])))
            self.chatPageState.addEffectUponIsPresented(
                changedTo: false,
                id: .deeplinkToOtherChat
            ) {
                Application.dismissSheets()
                navigation.navigate(to: .userContent(.push(.chat(conversation))))
            }
        }

        return .success([.sound])
    }

    // MARK: - Auxiliary

    private func generateAccessToken() async -> Callback<String, Exception> {
        guard let url = URL(string: "https://us-central1-jaguar-5d735.cloudfunctions.net/generateAccessToken") else {
            return .failure(.init(
                "Failed to generate URL.",
                metadata: .init(sender: self)
            ))
        }

        do {
            let dataResult = try await urlSession.data(for: .init(url: url))

            guard let accessToken = String(data: dataResult.0, encoding: .utf8),
                  let urlResponse = dataResult.1 as? HTTPURLResponse,
                  (200 ..< 300).contains(urlResponse.statusCode) else {
                return .failure(.init(
                    "Failed to decode URL response or status did not indicate success.",
                    userInfo: [
                        "ResponseBody": String(
                            data: dataResult.0,
                            encoding: .utf8
                        ) ?? "<non-utf8>",
                        "URLResponseCode": (dataResult.1 as? HTTPURLResponse)?.statusCode ?? -1,
                    ],
                    metadata: .init(sender: self)
                ))
            }

            return .success(accessToken)
        } catch {
            return .failure(.init(
                error,
                metadata: .init(sender: self)
            ))
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
                body = (translations
                    .first(where: { $0.languagePair.to == user.languageCode })?
                    .output ?? translations
                    .first(where: { $0.languagePair.from == user.languageCode })?
                    .input
                    .value)?.sanitized
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
        let userInfo = ["UserID": user.id]

        guard let currentUser = clientSession.user.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        let newBadgeNumber = await user.hostedBadgeNumber + 1
        if let exception = await updateHostedBadgeNumber(
            newBadgeNumber,
            user: user
        ) {
            return exception
        }

        guard let pushTokens = user.pushTokens else {
            return .init(
                "The specified user has not registered for push notifications.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        let userNumberHash = currentUser.phoneNumber.nationalNumberString.digits.encodedHash
        for pushToken in pushTokens {
            if let exception = await sendNotification(
                title: title,
                body: body ?? .bangQualifiedEmpty,
                badgeNumber: newBadgeNumber,
                pushToken: pushToken,
                userInfo: [
                    "conversationIDKey": conversationIDKey,
                    "isReaction": isReaction ? "true" : "false",
                    "recipientUserID": user.id,
                    "userNumberHash": userNumberHash,
                ],
                isReaction: isReaction
            ) {
                return exception.appending(userInfo: userInfo)
            }
        }

        return nil
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
    ) async -> Exception? {
        let generateAccessTokenResult = await generateAccessToken()

        switch generateAccessTokenResult {
        case let .success(accessToken):
            guard let url = URL(string: "https://fcm.googleapis.com/v1/projects/jaguar-5d735/messages:send") else {
                return .init(
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

            request.setValue(
                "Bearer \(accessToken)",
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
                    return .init(
                        "Failed to decode URL response or status did not indicate success.",
                        isReportable: !responseBody.contains("UNREGISTERED"),
                        userInfo: [
                            "ResponseBody": responseBody,
                            "URLResponseCode": responseCode,
                        ],
                        metadata: .init(sender: self)
                    )
                }

                return nil
            } catch {
                return .init(
                    error,
                    metadata: .init(sender: self)
                )
            }

        case let .failure(exception):
            return exception
        }
    }

    private func updateHostedBadgeNumber(
        _ badgeNumber: Int? = nil,
        user: User
    ) async -> Exception? {
        switch user.id == User.currentUserID {
        case true:
            var newBadgeNumber = badgeNumber
            if newBadgeNumber == nil {
                newBadgeNumber = await user.calculateBadgeNumber()
            }

            guard let newBadgeNumber else {
                return .init(
                    "Failed to resolve badge number.",
                    metadata: .init(sender: self)
                )
            }

            return await networking.database.setValue(
                newBadgeNumber < 0 ? 0 : newBadgeNumber,
                forKey: "\(NetworkPath.users.rawValue)/\(user.id)/\(User.SerializationKeys.badgeNumber.rawValue)"
            )

        case false:
            guard let badgeNumber else {
                return .init(
                    "Must supply badge number for users other than current user.",
                    metadata: .init(sender: self)
                )
            }

            return await networking.database.setValue(
                badgeNumber < 0 ? 0 : badgeNumber,
                forKey: "\(NetworkPath.users.rawValue)/\(user.id)/\(User.SerializationKeys.badgeNumber.rawValue)"
            )
        }
    }
}

// swiftlint:enable file_length type_body_length
