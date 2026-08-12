//
//  ChangeLanguagePageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking
import Translator

/// The service that applies the user's language selection from the language change page.
///
/// Use ``ChangeLanguagePageViewService`` to confirm and apply a new app language. Applying a
/// language persists it to the current user's remote record and resets the app, which must
/// restart for the change to take effect.
struct ChangeLanguagePageViewService {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService

    // MARK: - Reducer Action Handlers

    /// Asks the user to confirm the language change, applying it if they accept.
    ///
    /// Confirmation warns that the app must restart. If the user accepts, the new language is
    /// written to the current user's remote record in a single atomic update, together with a
    /// language history that records the outgoing language only when messages were sent or
    /// received in it. The app then resets – preserving the current user's identifier – and
    /// exits. Failures surface as a toast.
    ///
    /// - Parameter selectedLanguageCode: The language code of the selected language.
    func confirmButtonTapped(_ selectedLanguageCode: String) {
        Task {
            let applyAndExitAction: AKAction = .init(
                "Apply & Exit",
                style: .destructivePreferred
            ) {
                Task {
                    do throws(Exception) {
                        try await changeLanguage(
                            to: selectedLanguageCode
                        )
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            await AKActionSheet(
                title: "Change Language to ⌘\(selectedLanguageCode.languageExonym ?? selectedLanguageCode.uppercased())⌘",
                message: "You must restart the app for this to take effect.",
                actions: [
                    applyAndExitAction,
                    .cancelAction,
                ],
                sourceItem: .custom(.string(
                    "Confirm".localized
                ))
            ).present(translating: [
                .actions([applyAndExitAction]),
                .message,
                .title,
            ])
        }
    }

    // MARK: - Auxiliary

    private func changeLanguage(
        to languageCode: String
    ) async throws(Exception) {
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        defer { core.hud.hide() }

        let loadedData = LockIsolated<Bool?>(nil)
        let timeout = Timeout(after: .seconds(1)) {
            Task { @MainActor in
                guard loadedData.wrappedValue != true else { return }
                core.ui.addOverlay(
                    alpha: 0.5,
                    activityIndicator: nil,
                    isModal: false
                )

                core.hud.showProgress(
                    text: Localized(
                        .settingLanguage,
                        languageCode: languageCode
                    ).wrappedValue,
                    isModal: true
                )
            }
        }

        try await userSession.resolveCurrentUser(
            and: .allDataTypes
        )

        let conversations = (
            userSession
                .currentUser?
                .conversations?
                .visibleForCurrentUser ?? []
        )

        let hasIncomingMessagesInCurrentLanguage = conversations
            .filter { !($0.users ?? []).compactMap(\.languageCode).contains(RuntimeStorage.languageCode) }
            .messageTranslations(fromCurrentUser: false)
            .compactMap(\.languagePair.to)
            .contains(RuntimeStorage.languageCode)

        let hasOutgoingMessagesInCurrentLanguage = conversations
            .messageTranslations(fromCurrentUser: true)
            .compactMap(\.languagePair.from)
            .contains(RuntimeStorage.languageCode)

        var newPreviousLanguageCodes = (currentUser.previousLanguageCodes ?? []).filter { $0 != languageCode }
        if hasIncomingMessagesInCurrentLanguage || hasOutgoingMessagesInCurrentLanguage {
            newPreviousLanguageCodes += [RuntimeStorage.languageCode]
        }

        newPreviousLanguageCodes = newPreviousLanguageCodes.unique.reversed()

        loadedData.wrappedValue = true
        timeout.cancel()

        // Both fields land in a single atomic write on the user node.
        _ = try await currentUser.update {
            Assign(
                \.languageCode,
                to: languageCode
            )
            Assign(
                \.previousLanguageCodes,
                to: newPreviousLanguageCodes.isEmpty
                    ? Array.bangQualifiedEmpty
                    : newPreviousLanguageCodes
            )
        }

        await MainActor.run {
            Application.reset(
                preserveCurrentUserID: true,
                onCompletion: .exitGracefully
            )
        }
    }
}

private extension [Conversation] {
    func messageTranslations(
        fromCurrentUser: Bool
    ) -> [Translation] {
        flatMap { $0.messages ?? [] }
            .filter { $0.isFromCurrentUser == fromCurrentUser }
            .flatMap { $0.translations ?? [] }
            .unique
    }
}
