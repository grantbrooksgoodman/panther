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

public struct ChangeLanguagePageViewService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser?.id) private var clientSessionCurrentUserID: String?
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking.database) private var database: DatabaseDelegate
    @Dependency(\.navigation) private var navigation: Navigation

    // MARK: - Properties

    private var currentUserID: String? {
        @Persistent(.currentUserID) var persistedCurrentUserID: String?
        return clientSessionCurrentUserID ?? persistedCurrentUserID
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
        guard let currentUserID else {
            return .init(
                "Current user ID has not been set.",
                metadata: [self, #file, #function, #line]
            )
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

        return nil
    }
}
