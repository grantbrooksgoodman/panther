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

public struct ChangeLanguagePageViewService {
    // MARK: - Dependencies

    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.networking.database) private var database: DatabaseDelegate
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    private var currentUserID: String? {
        @Persistent(.currentUserID) var currentUserID: String?
        return userSession.currentUser?.id ?? currentUserID
    }

    // MARK: - Reducer Action Handlers

    public func confirmButtonTapped(_ selectedLanguageCode: String) {
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
                ]
            ).present()
        }
    }

    // MARK: - Auxiliary

    private func changeLanguage(to languageCode: String) async -> Exception? {
        guard let currentUserID,
              let currentUser = userSession.currentUser else {
            return .init(
                "Failed to resolve required values.",
                metadata: [self, #file, #function, #line]
            )
        }

        defer { coreHUD.hide() }

        var loadedData = false
        let timeout = Timeout(after: .seconds(1)) {
            guard !loadedData else { return }
            coreHUD.showProgress(
                text: Localized(.settingLanguage).wrappedValue,
                isModal: true
            )
        }

        if let exception = await currentUser.setConversations() {
            return exception
        }

        for conversation in (currentUser.conversations ?? [])
            .visibleForCurrentUser
            .filter({
                !$0.messageIDs.isBangQualifiedEmpty && ($0.messages == nil || $0.messages?.isEmpty == true)
            }) {
            if let exception = await conversation.setMessages() {
                return exception
            }
        }

        if let exception = await currentUser.conversations?.visibleForCurrentUser.setUsers() {
            return exception
        }

        loadedData = true
        timeout.cancel()

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

        let updateValueResult = await currentUser.updateValue(
            newPreviousLanguageCodes.sorted().unique,
            forKey: .previousLanguageCodes
        )

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

            Application.reset(
                preserveCurrentUserID: true,
                onCompletion: .exitGracefully
            )

        case let .failure(exception):
            return exception
        }

        return nil
    }
}

private extension Array where Element == Conversation {
    func messageTranslations(
        fromCurrentUser: Bool
    ) -> [Translation] {
        compactMap(\.messages)
            .reduce([], +)
            .filter { fromCurrentUser ? $0.isFromCurrentUser : !$0.isFromCurrentUser }
            .compactMap(\.translations)
            .reduce([], +)
            .unique
    }
}
