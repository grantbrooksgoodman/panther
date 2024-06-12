//
//  InviteService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import CoreArchitecture

public struct InviteService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.uiApplication.keyWindow?.rootViewController) private var keyViewController: UIViewController?
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService

    // MARK: - Present Invitation Prompt

    public func presentInvitationPrompt() async -> Exception? {
        guard let presentInviteLanguagePicker = await promptToTranslate() else { return nil }

        guard presentInviteLanguagePicker else {
            if let exception = await composeInvitation(languageCode: nil) {
                return exception
            }

            return nil
        }

        Task { @MainActor in
            keyViewController?.dismiss(animated: true)
        }

        coreGCD.after(.seconds(2)) {
            RootSheets.present(.inviteLanguagePicker)
        }

        return nil
    }

    // MARK: - Compose Invitation

    public func composeInvitation(languageCode: String?) async -> Exception? {
        guard let appShareLink = services.metadata.appShareLink else {
            if let exception = await services.metadata.resolveValues() {
                return exception
            }

            return await composeInvitation(languageCode: languageCode)
        }

        // swiftlint:disable:next line_length
        let promptMessage = "Hey, let's chat on *\(build.finalName)*! It's a simple messaging app that allows us to easily talk to each other in our native languages!"

        services.analytics.logEvent(.invite)

        guard languageCode != "en" else {
            let textMessage = "\(promptMessage.sanitized)\n\n\(appShareLink.absoluteString)"
            return services.textMessage.composeTextMessage(textMessage)
        }

        let translateResult = await translator.translate(
            .init(promptMessage),
            with: .init(from: "en", to: languageCode ?? RuntimeStorage.languageCode),
            hud: (.seconds(1), true)
        )

        switch translateResult {
        case let .success(translation):
            let textMessage = "\(translation.output)\n\n\(appShareLink.absoluteString)"
            if let exception = services.textMessage.composeTextMessage(textMessage) {
                return exception
            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Prompt to Translate

    /// - Returns: An optional`Bool` representing whether or not the user would like to translate the invitation. Will be `nil` if the user cancels the operation.
    private func promptToTranslate() async -> Bool? {
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
