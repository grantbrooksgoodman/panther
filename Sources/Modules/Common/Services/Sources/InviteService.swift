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

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

struct InviteService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.onboardingService.createdUserInCurrentAppSession) private var createdUserInCurrentAppSession: Bool
    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.uiApplication.keyViewController?.view) private var keyView: UIView?
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Properties

    @Persistent(.appOpenCount) private var appOpenCount: Int?
    @Persistent(.contactPairArchive) private var contactPairArchive: [ContactPair]?

    // MARK: - Computed Properties

    private var canSuggestInvitation: Bool {
        let sufficientAppOpenCount = (appOpenCount ?? 0) == 0 || appOpenCount == 1 || (appOpenCount ?? 0) % 2 == 0
        guard services.permission.contactPermissionStatus == .granted,
              (contactPairArchive ?? []).isEmpty,
              currentUser?.conversations == nil || currentUser?.conversations?.isEmpty == true,
              currentUser?.conversationIDs == nil || currentUser?.conversationIDs?.isEmpty == true,
              createdUserInCurrentAppSession || sufficientAppOpenCount else { return false }
        return true
    }

    // MARK: - Compose Invitation

    @MainActor
    func composeInvitation(languageCode: String?) async -> Exception? {
        guard let appShareLink = services.metadata.appShareLink else {
            if let exception = await services.metadata.resolveValues() {
                return exception
            }

            return await composeInvitation(languageCode: languageCode)
        }

        // swiftlint:disable:next line_length
        let promptMessage = "Hey, let's chat on ⌘\(build.finalName)⌘! It's a simple messaging app that allows us to easily talk to each other in our native languages!"

        services.analytics.logEvent(.invite)

        guard languageCode != "en" else {
            presentActivityViewController(
                appShareLink: appShareLink,
                text: promptMessage.sanitized
            )

            return nil
        }

        let translateResult = await translator.translate(
            .init(promptMessage),
            with: .init(from: "en", to: languageCode ?? RuntimeStorage.languageCode),
            hud: (.zero, true)
        )

        switch translateResult {
        case let .success(translation):
            presentActivityViewController(
                appShareLink: appShareLink,
                text: translation.output
            )

            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Present Invitation Prompt

    @MainActor
    func presentInvitationPrompt() async -> Exception? {
        guard let shouldPresentInviteLanguagePicker = await presentTranslationAlert() else { return nil }
        guard shouldPresentInviteLanguagePicker else {
            if let exception = await composeInvitation(languageCode: nil) {
                return exception
            }

            return nil
        }

        Application.dismissSheets()
        core.gcd.after(.seconds(2)) {
            RootSheets.present(.inviteLanguagePicker)
        }

        return nil
    }

    // MARK: - Present Invitation Suggestion Prompt

    func presentInvitationSuggestionPrompt() async {
        let inviteAction: AKAction = .init(
            "Send Invite",
            style: .preferred
        ) {
            Task {
                if let exception = await self.presentInvitationPrompt() {
                    Logger.log(exception, with: .toast)
                }
            }
        }

        await AKAlert( // swiftlint:disable:next line_length
            message: "It doesn't appear that any of your contacts have an account on ⌘\(build.finalName)⌘ yet.\n\nWould you like to send them an invite to sign up?",
            actions: [inviteAction, .cancelAction]
        ).present(translating: [.actions([inviteAction]), .message])
    }

    // MARK: - Suggest Invitation If Needed

    /// - Returns: `true` if the necessary conditions to suggest invitation were met.
    func suggestInvitationIfNeeded() async -> Bool {
        guard canSuggestInvitation else { return false }

        if let exception = await services.contact.syncContactPairArchive() {
            Logger.log(exception, with: .toast)
            return false
        }

        guard (contactPairArchive ?? []).isEmpty else { return false }
        await presentInvitationSuggestionPrompt()
        return true
    }

    // MARK: - Auxiliary

    @MainActor
    private func presentActivityViewController(
        appShareLink: URL,
        text: String
    ) {
        let activityVC = UIActivityViewController(
            activityItems: [appShareLink, text],
            applicationActivities: nil
        )

        activityVC.popoverPresentationController?.sourceView = keyView
        core.ui.present(activityVC)
    }

    /// - Returns: An optional`Bool` representing whether or not the user would like to translate the invitation. Will be `nil` if the user cancels the operation.
    private func presentTranslationAlert() async -> Bool? {
        var shouldTranslate: Bool?

        let acceptTranslationAction: AKAction = .init("Yes, translate", style: .preferred) {
            shouldTranslate = true
        }

        let rejectTranslationAction: AKAction = .init("No, don't translate") {
            shouldTranslate = false
        }

        await AKAlert(
            title: "Translate Invitation",
            message: "Would you like ⌘\(build.finalName)⌘ to translate the invitation message into another language?",
            actions: [
                acceptTranslationAction,
                rejectTranslationAction,
                .cancelAction,
            ]
        ).present(translating: [
            .actions([acceptTranslationAction, rejectTranslationAction]),
            .message,
            .title,
        ])

        return shouldTranslate
    }
}
