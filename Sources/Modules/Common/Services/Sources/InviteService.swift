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

/// Use ``InviteService`` to invite the user's contacts to the app.
///
/// The service composes invitation messages – translated into a language of the user's choice –
/// and presents the system share sheet for sending them.
@MainActor
struct InviteService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.onboardingService.createdUserInCurrentAppSession) private var createdUserInCurrentAppSession: Bool
    @Dependency(\.clientSession.entity.user.currentUser) private var currentUser: User?
    @Dependency(\.uiApplication.keyViewController?.view) private var keyView: UIView?
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Properties

    @Persistent(.appOpenCount) private var appOpenCount: Int?

    // MARK: - Computed Properties

    private var canSuggestInvitation: Bool {
        let sufficientAppOpenCount = (appOpenCount ?? 0) == 0 || appOpenCount == 1 || (appOpenCount ?? 0) % 2 == 0
        guard services.permission.contactPermissionStatus == .granted,
              !services.contact.hasContactsBesidesCurrentUser,
              currentUser?.conversations == nil || currentUser?.conversations?.isEmpty == true,
              currentUser?.conversationIDs == nil || currentUser?.conversationIDs?.isEmpty == true,
              createdUserInCurrentAppSession || sufficientAppOpenCount else { return false }
        return true
    }

    // MARK: - Compose Invitation

    /// Composes an app invitation and presents the system share sheet for sending it.
    ///
    /// The invitation contains the app's share link and a prompt message translated into the
    /// given language. If the app share link has not yet been resolved, remote metadata is
    /// resolved first.
    ///
    /// - Parameter languageCode: The language code into which to translate the invitation
    ///   message. Pass `nil` to target the system language. If the given language code is
    ///   `en`, the message is not translated.
    ///
    /// - Throws: An `Exception` if metadata resolution or translation fails.
    func composeInvitation(languageCode: String?) async throws(Exception) {
        guard let appShareLink = services.metadata.appShareLink else {
            try await services.metadata.resolveValues()
            return try await composeInvitation(
                languageCode: languageCode
            )
        }

        // swiftlint:disable:next line_length
        let promptMessage = "Hey, let's chat on ⌘\(build.finalName)⌘! It's a simple messaging app that allows us to easily talk to each other in our native languages!"

        services.analytics.logEvent(.invite)
        guard languageCode != "en" else {
            return presentActivityViewController(
                appShareLink: appShareLink,
                text: promptMessage.sanitized
            )
        }

        try await presentActivityViewController(
            appShareLink: appShareLink,
            text: translator.translate(
                .init(promptMessage),
                with: .init(from: "en", to: languageCode ?? RuntimeStorage.languageCode),
                hud: (.zero, true),
                enhance: .init(
                    additionalContext: "You are translating an invitation message."
                )
            ).output.sanitized
        )
    }

    // MARK: - Present Invitation Prompt

    /// Asks the user whether to translate the invitation before composing it.
    ///
    /// If the user declines translation, the invitation is composed targeting the system
    /// language. If the user accepts, all presented sheets are dismissed and the invite
    /// language picker is presented. Canceling the alert does nothing.
    ///
    /// - Throws: An `Exception` if composing the invitation fails.
    func presentInvitationPrompt() async throws(Exception) {
        guard let shouldPresentInviteLanguagePicker = await presentTranslationAlert() else {
            return
        }

        guard shouldPresentInviteLanguagePicker else {
            return try await composeInvitation(
                languageCode: nil
            )
        }

        Application.dismissSheets()
        Task.delayed(by: .seconds(2)) { @MainActor in
            RootSheets.present(.inviteLanguagePicker)
        }
    }

    // MARK: - Present Invitation Suggestion Prompt

    /// Presents an alert suggesting that the user invite their contacts to the app.
    ///
    /// If the user accepts, the invitation prompt is presented.
    func presentInvitationSuggestionPrompt() async {
        let inviteAction: AKAction = .init(
            "Send Invite",
            style: .preferred
        ) {
            Task { @MainActor in
                do throws(Exception) {
                    try await presentInvitationPrompt()
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
                }
            }
        }

        await AKAlert( // swiftlint:disable:next line_length
            message: "It doesn't appear that any of your contacts have an account on ⌘\(build.finalName)⌘ yet.\n\nWould you like to send them an invite to sign up?",
            actions: [inviteAction, .cancelAction]
        ).present(translating: [.actions([inviteAction]), .message])
    }

    // MARK: - Suggest Invitation If Needed

    /// Presents the invitation suggestion prompt if the user has no conversations and no
    /// registered contacts.
    ///
    /// The suggestion requires contact permission and is limited to qualifying app launches.
    /// Before presenting, this method syncs the contact pair archive to confirm that no
    /// contact besides the current user has an account.
    ///
    /// - Returns: `true` if the invitation suggestion was presented; otherwise, `false`.
    func suggestInvitationIfNeeded() async -> Bool {
        guard canSuggestInvitation else { return false }

        do {
            try await services.contact.syncContactPairArchive()
        } catch {
            Logger.log(
                error,
                with: .toast
            )

            return false
        }

        guard !services.contact.hasContactsBesidesCurrentUser else { return false }
        await presentInvitationSuggestionPrompt()
        return true
    }

    // MARK: - Auxiliary

    private func presentActivityViewController(
        appShareLink: URL,
        text: String
    ) {
        let activityVC = UIActivityViewController(
            activityItems: [appShareLink, text],
            applicationActivities: nil
        )

        activityVC.popoverPresentationController?.sourceView = keyView
        coreUI.present(activityVC)
    }

    /// - Returns: An optional`Bool` representing whether or not the user would like to translate the invitation. Will be `nil` if the user cancels the operation.
    private func presentTranslationAlert() async -> Bool? {
        let shouldTranslate = LockIsolated<Bool?>(nil)
        let acceptTranslationAction: AKAction = .init(
            "Yes, translate",
            style: .preferred
        ) { shouldTranslate.wrappedValue = true }

        let rejectTranslationAction: AKAction = .init(
            "No, don't translate"
        ) { shouldTranslate.wrappedValue = false }

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

        return shouldTranslate.wrappedValue
    }
}
