//
//  InviteService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import Redux

public struct InviteService {
    // MARK: - Dependencies

    @Dependency(\.analyticsService) private var analyticsService: AnalyticsService
    @Dependency(\.build) private var build: Build
    @Dependency(\.metadataService) private var metadataService: MetadataService
    @Dependency(\.textMessageService) private var textMessageService: TextMessageService
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService

    // MARK: - Compose Invitation

    public func composeInvitation(languageCode: String?) async -> Exception? {
        guard let appShareLink = metadataService.appShareLink else {
            if let exception = await metadataService.resolveValues() {
                return exception
            }

            return await composeInvitation(languageCode: languageCode)
        }

        // swiftlint:disable:next line_length
        let promptMessage = "Hey, let's chat on *\(build.finalName)*! It's a simple messaging app that allows us to easily talk to each other in our native languages!"

        analyticsService.logEvent(.invite)

        guard languageCode != "en" else {
            let textMessage = "\(promptMessage.sanitized)\n\n\(appShareLink.absoluteString)"
            return textMessageService.composeTextMessage(textMessage)
        }

        let translateResult = await translator.translate(
            .init(promptMessage),
            with: .init(from: "en", to: languageCode ?? RuntimeStorage.languageCode),
            hud: (.seconds(1), true)
        )

        switch translateResult {
        case let .success(translation):
            let textMessage = "\(translation.output)\n\n\(appShareLink.absoluteString)"
            textMessageService.composeTextMessage(textMessage)

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Prompt to Translate

    /// - Returns: An optional`Bool` representing whether or not the user would like to translate the invitation. Will be `nil` if the user cancels the operation.
    public func promptToTranslate() async -> Bool? {
        let message = "Would you like *\(build.finalName)* to translate the invitation message into another language?"
        let actions: [AKAction] = [.init(
            title: "Yes, translate",
            style: .preferred
        ),
        .init(
            title: "No, don't translate",
            style: .default
        )]
        let alert: AKAlert = .init(
            title: "Translate Invitation",
            message: message,
            actions: actions,
            networkDependent: true
        )

        let actionID = await alert.present()
        guard actionID != -1 else { return nil }
        return actionID == actions[0].identifier
    }
}

/* MARK: TextMessageService Dependency */

public enum TextMessageServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> TextMessageService {
        .init()
    }
}

public extension DependencyValues {
    var textMessageService: TextMessageService {
        get { self[TextMessageServiceDependency.self] }
        set { self[TextMessageServiceDependency.self] = newValue }
    }
}
