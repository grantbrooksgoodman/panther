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

struct ChangeLanguagePageViewService {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking.database) private var database: DatabaseDelegate
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Reducer Action Handlers

    func confirmButtonTapped(_ selectedLanguageCode: String) {
        Task {
            let applyAndExitAction: AKAction = .init(
                "Apply & Exit",
                style: .destructivePreferred
            ) {
                Task {
                    if let exception = await changeLanguage(to: selectedLanguageCode) {
                        Logger.log(exception, with: .toast)
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

    private func changeLanguage(to languageCode: String) async -> Exception? {
        guard let currentUserID = User.currentUserID,
              let currentUser = userSession.currentUser else {
            return .init(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        defer { core.hud.hide() }

        let loadedData = LockBox<Bool>()
        let timeout = Timeout(after: .seconds(1)) {
            Task { @MainActor in
                guard loadedData.value != true else { return }
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

        if let exception = await currentUser.setConversations() {
            return exception
        }

        for conversation in (currentUser.conversations ?? [])
            .visibleForCurrentUser
            .map(\.filteringSystemMessages)
            .filter({
                !$0.messageIDs.isBangQualifiedEmpty &&
                    ($0.messages == nil || $0.messages?.isEmpty == true) ||
                    $0.messageIDs.count != $0.messages?.count
            }) {
            if let exception = await conversation.setMessages() {
                return exception
            }
        }

        if let exception = await currentUser.conversations?.visibleForCurrentUser.setUsers() {
            return exception
        }

        let conversations = (currentUser.conversations?.visibleForCurrentUser ?? [])

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
        let updateValueResult = await currentUser.updateValue(
            newPreviousLanguageCodes.isEmpty ? Array.bangQualifiedEmpty : newPreviousLanguageCodes,
            forKey: .previousLanguageCodes
        )

        loadedData.value = true
        timeout.cancel()

        switch updateValueResult {
        case let .success(user):
            if let exception = userSession.setCurrentUser(user) {
                return exception
            }

            if let exception = await database.setValue(
                languageCode,
                forKey: "\(NetworkPath.users.rawValue)/\(currentUserID)/\(User.SerializationKeys.languageCode.rawValue)"
            ) {
                return exception
            }

            await MainActor.run {
                Application.reset(
                    preserveCurrentUserID: true,
                    onCompletion: .exitGracefully
                )
            }

        case let .failure(exception):
            return exception
        }

        return nil
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
